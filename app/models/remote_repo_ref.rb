class RemoteRepoRef < ActiveRecord::Base
  belongs_to :repo, :class_name => 'RemoteRepo', :foreign_key => 'remote_repo_id'

  validates :repo, :presence => true
  validates :name, :presence => true, :uniqueness => { :scope => :remote_repo_id }

  def uri
    [repo.uri.chomp('/'), 'commits', name].join('/')
  end
end
