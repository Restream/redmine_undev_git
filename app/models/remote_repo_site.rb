# remote repository storage service like github.com, gitlab.com, bitbucket.com, etc

class RemoteRepoSite < ActiveRecord::Base

  has_many :repos,
           class_name: 'RemoteRepo',
           foreign_key: 'remote_repo_site_id',
           inverse_of: :site

  has_many :revisions, through: :repos

  has_many :user_mappings, class_name: 'RemoteRepoSiteUser', foreign_key: 'remote_repo_site_id'

  validates :server_name, presence: true, uniqueness: true


  # find user by committer or author email with site mappings (email on site => redmine user)
  def find_user_by_email(email)
    mapping = user_mappings.where(email: email).first
    return mapping.user if mapping

    User.find_by_mail(email)
  end

  def uri
    "https://#{server_name}"
  end

  def all_committers_with_mappings
    unmapped = revisions.where(:committer_id => nil).pluck(:committer_email)
    unmapped.map! { |e| [e, nil] }
    mapped = user_mappings.all.map { |m| [m.email, m.user_id] }
    (mapped + unmapped).sort_by { |e| e[0] }
  end

end
