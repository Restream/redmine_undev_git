class ProjectHook < HookBase

  acts_as_list :scope => '(project_id = #{project_id} AND repository_id #{repository_id ? "= #{repository_id}" : "IS NULL"})'

  safe_attributes %w{project_id repository_id}

  validate :project, :presence => true

  belongs_to :project
  belongs_to :repository

  # project hooks for all repos
  scope :global, where(:repository_id => nil)
end
