# remote repository storage service like github.com, gitlab.com, bitbucket.com, etc

class RemoteRepoSite < ActiveRecord::Base

  has_many :repos, :class_name => 'RemoteRepo', :foreign_key => 'site_id'

  validates :server_name, :presence => true

end
