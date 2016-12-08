class ProjectHook < HookBase

  acts_as_list scope: '(project_id = #{project_id} AND repository_id #{repository_id ? "= #{repository_id}" : "IS NULL"})'

  safe_attributes %w{project_id repository_id}

  validates :project, presence: true

  belongs_to :project
  belongs_to :repository

  # project hooks for all repos
  scope :global, -> { where(repository_id: nil) }

  # Users/groups issues can be assigned to
  def assignable_users
    project.assignable_users
  end

  def available_custom_fields
    project ? project.all_issue_custom_fields : []
  end

  def to_s
    "#{super}; project: #{project.try(:identifier)}; repository: #{repository_id}"
  end
end
