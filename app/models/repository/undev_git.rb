require 'redmine/scm/adapters/undev_git_adapter'

class Repository::UndevGit < Repository

  class UrlValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      regexp = /\A([\w\d\-_\.]+@[\w\d\-_\.]+:[\w\d\-_\.\/]+)|(https?|git|ssh):\/\/[\w\d\-_\.\/@:]+\z/
      unless (value =~ regexp) || File.readable_real?(value)
        record.errors.add(attribute, I18n.t(:repository_url_malformed))
      end
    end
  end

  # root_url stores path to local bare repository
  attr_protected :root_url

  safe_attributes 'use_init_hooks', 'use_init_refs', 'fetch_by_web_hook'

  # Storage folder for local copies of remote repositories
  cattr_accessor :repo_storage_dir
  self.repo_storage_dir = Redmine::Configuration['scm_repo_storage_dir'] || begin
    rpath = Rails.root.join('repos')
    rpath.symlink? ? File.readlink(rpath) : rpath
  end

  has_many :hooks,
           :class_name => 'ProjectHook',
           :foreign_key => 'repository_id',
           :dependent => :destroy

  validates :project, presence: true
  validates :url, presence: true, url: true
  validate :url_uniqueness_check

  after_destroy :remove_repository_folder

  class << self

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

  def scm
    initialize_root_url
    super

    unless @scm.cloned?

      #try to clone twice
      begin
        @scm.clone_repository
      rescue Redmine::Scm::Adapters::CommandFailed
        @scm.clone_repository
      end
    end
    @scm
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

  def supports_directory_revisions?
    true
  end

  def supports_revision_graph?
    true
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

  def use_init_hooks
    extra_info && extra_info[:use_init_hooks]
  end

  def use_init_hooks?
    use_init_hooks.to_i > 0
  end

  def use_init_hooks=(val)
    merge_extra_info(:use_init_hooks => val)
  end

  def use_init_refs
    extra_info && extra_info[:use_init_refs]
  end

  def use_init_refs?
    use_init_refs.to_i > 0
  end

  def use_init_refs=(val)
    merge_extra_info(:use_init_refs => val)
  end

  def fetch_by_web_hook
    extra_info && extra_info[:fetch_by_web_hook]
  end

  def fetch_by_web_hook?
    fetch_by_web_hook.to_i > 0
  end

  def fetch_by_web_hook=(val)
    merge_extra_info(:fetch_by_web_hook => val)
  end

  def initialization_done?
    extra_info && extra_info['heads'] && extra_info['heads'].any?
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

  def initial_apply_hooks(changeset, issue, keywords)
    all_hooks = all_applicable_hooks

    hooks = []

    # hook for any branch have the less priority then hook for specific branch
    hook_for_any_branch = all_hooks.detect { |h| h.any_branch? && h.applied_for?(keywords, changeset.branches) }

    # find hook for every branch
    changeset.branches.each do |branch|
      specific_hook = all_hooks.detect { |h| !h.any_branch? && h.applied_for?(keywords, [branch]) }
      hooks << specific_hook if specific_hook
    end

    # execute hook for any branch only if specific hooks not found
    hooks << hook_for_any_branch if hook_for_any_branch && hooks.empty?

    hooks.each do |hook|
      hook.apply_for_issue_by_changeset(issue, changeset)
    end
  end

  def apply_hooks_for_merged_commits(prev_branches, repo_branches)
    return unless initialization_done? || use_init_hooks?

    all_hooks = all_applicable_hooks.find_all { |b| !b.any_branch? }
    hook_branches = all_hooks.map(&:branches).flatten.uniq
    hook_branches.each do |hook_branch|

      repo_branch = repo_branches.find { |b| b.to_s == hook_branch }
      prev_branch = prev_branches[hook_branch]
      next unless repo_branch

      opts = {}
      opts[:reverse]  = true
      opts[:excludes] = [prev_branch] if prev_branch.present?
      opts[:includes] = [repo_branch.scmid]

      revisions = scm.revisions('', nil, nil, opts)
      next if revisions.blank?

      limit = 300
      offset = 0
      while offset < revisions.size
        scmids = revisions.slice(offset, limit).map { |r| r.scmid }
        cs = changesets.where('scmid IN (?)', scmids).order('committed_on DESC')
        cs.each do |changeset|

          # branches added to changeset at the first save
          # for all these branches hooks was already applied
          next if changeset.branches.include?(hook_branch)

          apply_hooks_for_branch(changeset, hook_branch)
        end
        offset += limit
      end
    end
  end

  def all_applicable_hooks
    hooks.by_position + project.hooks.global.by_position + GlobalHook.by_position
  end

  def apply_hooks_for_branch(changeset, branch)
    ref_keywords = Setting.commit_ref_keywords
    all_hooks = all_applicable_hooks
    fix_keywords = all_hooks.map(&:keywords).join(',')

    parsed = changeset.parse_comment_for_issues(ref_keywords, fix_keywords)

    # update changeset only if
    # changeset was not rebased
    # initialization done or using hooks for initialization is allowed
    if changeset.rebased_from.nil? && (initialization_done? || use_init_hooks?)

      # change issues by hooks
      parsed[:fix_issues].each do |issue, keywords|

        # ignore closed issues
        next if issue.closed?

        hook = all_hooks.detect do |h|
          !h.any_branch? && h.applied_for?(keywords, [branch])
        end
        hook.apply_for_issue_by_changeset(issue, changeset) if hook
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

  def url_uniqueness_check
    if url.present? && url_changed? && same_url_repo = Repository.find_by_url(url)

      if same_url_repo.identifier.present?
        url_error = l(:repository_taken, project: same_url_repo.project, identifier: same_url_repo.identifier)
      else
        url_error = l(:repository_taken_without_id, project: same_url_repo.project)
      end

      errors.add(:url, url_error)
      false
    else
      true
    end
  end

  def initialize_root_url
    if root_url.blank?
      root_url = File.join(self.repo_storage_dir, project.identifier, id.to_s)
      update_attribute(:root_url, root_url)
    end
  end

  def remove_repository_folder
    FileUtils.remove_entry_secure(root_url) if root_url.present? && Dir.exists?(root_url)
  end
end
