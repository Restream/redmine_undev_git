class RemoteRepo < ActiveRecord::Base
  belongs_to :site, :class_name => 'RemoteRepoSite'
  has_many :revisions,
           :class_name => 'RemoteRepoRevision',
           :dependent => :destroy # todo: should delete_all for all tails

  validates :site, :presence => true

  serialize :tail_revisions, Array

  def fetch
    fetch_service = RedmineUndevGit::Services::RemoteRepoFetch.new(self)
    fetch_service.fetch
  end
end
