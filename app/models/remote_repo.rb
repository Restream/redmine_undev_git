class RemoteRepo < ActiveRecord::Base
  belongs_to :site, :class_name => 'RemoteRepoSite', :foreign_key => 'remote_repo_site_id'
  has_many :revisions,
           :class_name => 'RemoteRepoRevision',
           :inverse_of => :repo,
           :dependent => :destroy # todo: should delete_all for all tails
  has_many :refs, :class_name => 'RemoteRepoRef', :inverse_of => :repo

  validates :site, :presence => true

  serialize :tail_revisions, Array

  def fetch
    fetch_service = RedmineUndevGit::Services::RemoteRepoFetch.new(self)
    fetch_service.fetch
  end

  def uri
    [site.uri.chomp('/'), path_to_repo].join('/')
  end

  def find_revision(sha)
    revisions.where("#{RemoteRepoRevision.table_name}.sha like ?", "#{sha}%").first
  end
end
