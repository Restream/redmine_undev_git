module RedmineUndevGit::Includes::RepoFetch
  extend ActiveSupport::Concern

  module ClassMethods

    def human_attribute_name(attribute_key_name, *args)
      attr_name = attribute_key_name.to_s
      if attr_name == 'url'
        attr_name = 'path_to_repository'
      end
      super(attr_name, *args)
    end

    def scm_adapter_class
      Redmine::Scm::Adapters::UndevGitAdapter
    end

    def scm_name
      'UndevGit'
    end

    # Returns the identifier for the given git changeset
    def changeset_identifier(changeset)
      changeset.scmid
    end

    # Returns the readable identifier for the given git changeset
    def format_changeset_identifier(changeset)
      changeset.revision[0, 9]
    end
  end

  def report_last_commit
    extra_report_last_commit
  end

  def extra_report_last_commit
    return false if extra_info.nil?
    v = extra_info['extra_report_last_commit']
    return false if v.nil?
    v.to_s != '0'
  end

  def repo_log_encoding
    'UTF-8'
  end

  def branches
    scm.branches
  end

  def tags
    scm.tags
  end

  def default_branch
    scm.default_branch
  rescue Exception => e
    logger.error "git: error during get default branch: #{e.message}"
    nil
  end

  def find_changeset_by_name(name)
    if name.present?
      changesets.where(:revision => name.to_s).first ||
          changesets.where('scmid LIKE ?', "#{name}%").first
    end
  end

  def entries(path=nil, identifier=nil)
    entries = scm.entries(path, identifier, :report_last_commit => extra_report_last_commit)
    load_entries_changesets(entries)
    entries
  end

  def fetch_changesets
    fetch_start = Time.now
    @scm = nil
    scm.fetch!

    repo_branches = branches
    return if repo_branches.nil? || repo_branches.empty?
    prev_branches = previous_branches

    repo_heads = repo_branches.map{ |br| br.scmid }
    prev_heads = previous_heads
    return if prev_heads.sort == repo_heads.sort

    save_revisions(prev_heads, repo_heads)

    # don't apply hooks for already prepared changesets in first fetch
    apply_hooks_for_merged_commits(prev_branches, repo_branches) unless prev_branches.empty?

    h1 = extra_info || {}
    h  = h1.dup
    h['heads'] = repo_heads.dup
    h['branches'] ||= {}
    repo_branches.each { |b| h['branches'][b.to_s] = b.scmid }
    merge_extra_info(h)
    self.save
    fetch_events.create(:successful => true,
                        :duration => Time.now - fetch_start)
  rescue Exception => e
    fetch_events.create(:successful => false,
                        :duration => Time.now - fetch_start,
                        :error_message => e.message)
    raise
  end

  def latest_changesets(path,rev,limit=10)
    revisions = scm.revisions(path, nil, rev, :limit => limit, :all => false)
    return [] if revisions.nil? || revisions.empty?

    changesets.find(
        :all,
        :conditions => [
            'scmid IN (?)',
            revisions.map! { |c| c.scmid }
        ],
        :order => 'committed_on DESC'
    )
  end

  def initialization_done?
    extra_info && extra_info['heads'] && extra_info['heads'].any?
  end

  # returns :unknown, :green, :yellow or :red status
  def fetch_status
    return :green if fetch_successful?
    last_statuses = fetch_events.sorted.limit(Repository::RED_STATUS_THRESHOLD).pluck(:successful).uniq
    return :unknown if last_statuses.empty?
    return :yellow if last_statuses.length > 1
    last_statuses[0] ? :green : :red
  end

  private

  def previous_branches
    h1 = extra_info || {}
    h  = h1.dup
    h['branches'] ||= {}
  end

  def previous_heads
    h1 = extra_info || {}
    h  = h1.dup
    h['heads'] ||= []
  end

  def save_revisions(prev_db_heads, repo_heads)
    h = {}
    opts = {}
    opts[:reverse]  = true
    opts[:excludes] = prev_db_heads
    opts[:includes] = repo_heads

    revisions = scm.revisions('', nil, nil, opts)
    return if revisions.blank?

    limit = 100
    offset = 0
    revisions_copy = revisions.clone # revisions will change
    while offset < revisions_copy.size
      recent_changesets_slice = changesets.find(
          :all,
          :conditions => [
              'scmid IN (?)',
              revisions_copy.slice(offset, limit).map{|x| x.scmid}
          ]
      )
      # Subtract revisions that redmine already knows about
      recent_revisions = recent_changesets_slice.map{|c| c.scmid}
      revisions.reject!{|r| recent_revisions.include?(r.scmid)}
      offset += limit
    end

    revisions.each do |rev|
      transaction do
        # There is no search in the db for this revision, because above we ensured,
        # that it's not in the db.
        save_revision(rev)
      end
    end
  end

  def save_revision(rev)
    parents = (rev.parents || []).collect{|rp| find_changeset_by_name(rp)}.compact

    rebased_from = find_original_changeset(rev) if rev.looks_like_rebased?

    changeset = Changeset.create(
        :repository   => self,
        :revision     => rev.identifier,
        :scmid        => rev.scmid,
        :committer    => rev.author,
        :committed_on => rev.time,
        :comments     => rev.message,
        :parents      => parents,
        :branches     => rev.branches,
        :patch_id     => rev.patch_id,
        :authored_on  => rev.authored_on,
        :rebased_from => rebased_from
    )

    unless changeset.new_record?
      rev.paths.each { |change| changeset.create_change(change) }

      initial_parse_comments(changeset)
    end

    changeset
  end

  # find original changeset for revision that looks like rebased
  def find_original_changeset(rev)
    changesets.where(
        'patch_id = ? and committer = ? and authored_on = ? and revision <> ?',
        rev.patch_id,
        rev.author,
        rev.authored_on,
        rev.identifier
    ).first
  end

  def initial_parse_comments(changeset)
    ref_keywords = Setting.commit_ref_keywords
    all_hooks = all_applicable_hooks
    fix_keywords = all_hooks.map(&:keywords).join(',')

    parsed = changeset.parse_comment_for_issues(ref_keywords, fix_keywords)

    # make references to issues
    changeset.make_references_to_issues(parsed[:ref_issues]) if initialization_done? || use_init_refs?

    # update changeset only if
    # changeset was not rebased
    # initialization done or using hooks for initialization is allowed
    if changeset.rebased_from.nil? && (initialization_done? || use_init_hooks?)

      # change issues by hooks
      parsed[:fix_issues].each do |issue, keywords|

        # ignore closed issues
        next if issue.closed?

        initial_apply_hooks(changeset, issue, keywords)
      end

      # log time for issues
      if Setting.commit_logtime_enabled?
        parsed[:log_time].each do |issue, hours|
          changeset.log_time(issue, hours)
        end
      end
    end
  end

  def clear_extra_info_of_changesets
    return if extra_info.nil?
    v = extra_info['extra_report_last_commit']
    write_attribute(:extra_info, nil)
    h = {}
    h['extra_report_last_commit'] = v
    merge_extra_info(h)
    self.save(:validate => false)
  end
end
