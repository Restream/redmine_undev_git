class RemoteRepo < ActiveRecord::Base
  belongs_to :site, :class_name => 'RemoteRepoSite'

  def fetch
    fetch_service = RedmineUndevGit::Services::RemoteRepoFetch.new(self)
    fetch_service.fetch
  end
end
