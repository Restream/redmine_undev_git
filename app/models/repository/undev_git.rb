require 'redmine/scm/adapters/undev_git_adapter'

class Repository::UndevGit < Repository

  class UrlValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      regexp = /\A((\w+:\/\/(\S+@)*([\w\d\.]+)(:[\d]+)?\/*(\S*))|(file:\/\/(\S*))|((\S+@)*([\w\d\S]+):(\S*)))\z/
      unless (value =~ regexp) || File.readable_real?(value)
        record.errors.add(attribute, I18n.t(:repository_url_malformed))
      end
    end
  end

  # root_url stores path to local bare repository
  attr_protected :root_url

  safe_attributes 'use_init_hooks'

  # Storage folder for local copies of remote repositories
  cattr_accessor :repo_storage_dir
  self.repo_storage_dir = Redmine::Configuration['scm_repo_storage_dir'] || Rails.root.join('repos')

  has_many :hooks,
           :class_name => 'ProjectHook',
           :foreign_key => 'repository_id',
           :dependent => :destroy

  validates :project, presence: true
  validates :url, presence: true, url: true
  validate :url_uniqueness_check

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
      changeset.revision[0, 8]
    end

  end

  def scm
    initialize_root_url
    super
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

    scm_brs = branches
    return if scm_brs.nil? || scm_brs.empty?

    h1 = extra_info || {}
    h  = h1.dup
    repo_heads = scm_brs.map{ |br| br.scmid }
    h['heads'] ||= []
    prev_db_heads = h['heads'].dup
    if prev_db_heads.empty?
      prev_db_heads += heads_from_branches_hash
    end
    return if prev_db_heads.sort == repo_heads.sort

    h['db_consistent']  ||= {}
    if changesets.count == 0
      h['db_consistent']['ordering'] = 1
      merge_extra_info(h)
      self.save
    elsif ! h['db_consistent'].has_key?('ordering')
      h['db_consistent']['ordering'] = 0
      merge_extra_info(h)
      self.save
    end
    save_revisions(prev_db_heads, repo_heads)
  end

  def heads_from_branches_hash
    h1 = extra_info || {}
    h  = h1.dup
    h['branches'] ||= {}
    h['branches'].map { |br, hs| hs['last_scmid'] }
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
    !!use_init_hooks
  end

  def use_init_hook=(val)
    merge_extra_info(:use_init_hooks => val)
  end

  def initialization_done?
    extra_info && extra_info['heads'].any?
  end

  private

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
    h['heads'] = repo_heads.dup
    merge_extra_info(h)
    self.save
  end

  def save_revision(rev)
    parents = (rev.parents || []).collect{|rp| find_changeset_by_name(rp)}.compact

    rebased_from = find_original_changeset(rev) if rev.looks_like_rebased?

    changeset = Changeset.create!(
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
    rev.paths.each { |change| changeset.create_change(change) }

    parse_comments(changeset) if initialization_done? || use_init_hooks?

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

  def parse_comments(changeset)
    ref_keywords = Setting.commit_ref_keywords
    all_hooks = hooks.by_position + project.hooks.global.by_position + GlobalHook.by_position
    fix_keywords = all_hooks.map(&:keywords).join(',')

    parsed = changeset.parse_comment_for_issues(ref_keywords, fix_keywords)

    # make references to issues
    parsed[:ref_issues].each do |issue|
      issue.changesets << changeset
    end

    # change issues by hooks
    parsed[:fix_issues].each do |issue, keywords|
      hook = all_hooks.first { |h| h.applied_for?(keywords, changeset.branches) }
      hook.apply_for_issue_by_changeset(issue, changeset) if hook
    end

    # log time for issues
    if Setting.commit_logtime_enabled?
      parsed[:log_time].each do |issue, hours|
        changeset.log_time(issue, hours)
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
    self.save
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
end
