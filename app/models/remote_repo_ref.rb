class RemoteRepoRef < ActiveRecord::Base
  belongs_to :repo, :class_name => 'RemoteRepo'
end
