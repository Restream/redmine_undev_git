# remote repository storage service like github.com, gitlab.com, bitbucket.com, etc

class RemoteRepoSite < ActiveRecord::Base

  has_many :repos, :class_name => 'RemoteRepo', :foreign_key => 'remote_repo_site_id'
  has_many :user_mappings, :class_name => 'RemoteRepoSiteUser', :foreign_key => 'remote_repo_site_id'

  validates :server_name, :presence => true, :uniqueness => true


  # find user by committer or author email with site mappings (email on site => redmine user)
  def find_user_by_email(email)
    mapping = user_mappings.where(:email => email).first
    return mapping.user if mapping

    User.find_by_mail(email)
  end

end
