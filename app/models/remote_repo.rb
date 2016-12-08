class RemoteRepo < ActiveRecord::Base
  belongs_to :site, class_name: 'RemoteRepoSite', foreign_key: 'remote_repo_site_id'
  has_many :revisions,
    class_name: 'RemoteRepoRevision',
    inverse_of: :repo,
    dependent:  :destroy
  has_many :refs, class_name: 'RemoteRepoRef', inverse_of: :repo, dependent: :destroy
  has_many :applied_hooks, through: :revisions
  has_many :time_entries, through: :revisions

  validates :site, presence: true

  serialize :tail_revisions, Array

  scope :related_to_project, ->(project) {
    joins(revisions: :related_issues).where("#{Issue.table_name}.project_id = ?", project.id).uniq
  }

  def fetch
    fetch_service = create_fetch_service
    fetch_service.fetch
  end

  def refetch
    fetch_service = create_fetch_service
    fetch_service.refetch
  end

  def create_fetch_service
    RedmineUndevGit::Services::RemoteRepoFetch.new(self)
  end

  def uri
    [site.uri.chomp('/'), path_to_repo].join('/')
  end

  def find_revision(sha)
    revisions.where("#{RemoteRepoRevision.table_name}.sha like ?", "#{sha}%").first
  end

  def clear_time_entries
    TimeEntry.joins(remote_repo_revision: :repo).where("#{RemoteRepo.table_name}.id = ?", id).destroy_all
  end

  def clear_all
    clear_time_entries
    refs.clear
    revisions.clear
  end
end
