class RemoteRepoRef < ActiveRecord::Base
  belongs_to :repo, class_name: 'RemoteRepo', foreign_key: 'remote_repo_id'
  has_many :applied_hooks, class_name: 'RemoteRepoHook', dependent: :nullify

  validates :repo, presence: true
  validates :name, presence: true, uniqueness: { scope: :remote_repo_id }

  def uri
    [repo.uri.chomp('/'), 'commits', name].join('/')
  end
end
