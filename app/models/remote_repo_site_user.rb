class RemoteRepoSiteUser < ActiveRecord::Base

  belongs_to :site, :class_name => 'RemoteRepoSite', :foreign_key => 'remote_repo_site_id'
  belongs_to :user

  validates :site, :presence => true
  validates :email, :presence => true, :uniqueness => { :scope => :remote_repo_site_id }
  validates :user, :presence => true

end
