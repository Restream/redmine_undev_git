require 'redmine/scm/adapters/undev_git_adapter'

class Repository::UndevGit < Repository

  safe_attributes 'use_init_hooks', 'use_init_refs', 'fetch_by_web_hook'

  has_many :hooks,
           :class_name => 'ProjectHook',
           :foreign_key => 'repository_id',
           :dependent => :destroy

  validates :project, presence: true

  include RedmineUndevGit::Includes::RepoStore
  include RedmineUndevGit::Includes::RepoValidate
  include RedmineUndevGit::Includes::RepoFetch
  include RedmineUndevGit::Includes::RepoHooks

  def supports_directory_revisions?
    true
  end

  def supports_revision_graph?
    true
  end

  def use_init_hooks
    extra_info && extra_info[:use_init_hooks]
  end

  def use_init_hooks?
    use_init_hooks.to_i > 0
  end

  def use_init_hooks=(val)
    merge_extra_info(:use_init_hooks => val)
  end

  def use_init_refs
    extra_info && extra_info[:use_init_refs]
  end

  def use_init_refs?
    use_init_refs.to_i > 0
  end

  def use_init_refs=(val)
    merge_extra_info(:use_init_refs => val)
  end

  def fetch_by_web_hook
    extra_info && extra_info[:fetch_by_web_hook]
  end

  def fetch_by_web_hook?
    fetch_by_web_hook.to_i > 0
  end

  def fetch_by_web_hook=(val)
    merge_extra_info(:fetch_by_web_hook => val)
  end

  def all_applicable_hooks
    hooks.by_position + project.hooks.global.by_position + GlobalHook.by_position
  end

  def parent_dir_name
    project.identifier
  end
end
