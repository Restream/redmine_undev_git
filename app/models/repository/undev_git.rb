require 'redmine/scm/adapters/undev_git_adapter'

class Repository::UndevGit < Repository

  include RedmineUndevGit::Includes::RepoStore
  include RedmineUndevGit::Includes::RepoValidate
  include RedmineUndevGit::Includes::RepoFetch
  include RedmineUndevGit::Includes::RepoHooks

  safe_attributes 'use_init_hooks', 'use_init_refs', 'fetch_by_web_hook'

  has_many :hooks,
    class_name:  'ProjectHook',
    foreign_key: 'repository_id',
    dependent:   :destroy

  validates :project, presence: true

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
    merge_extra_info(use_init_hooks: val)
  end

  def use_init_refs
    extra_info && extra_info[:use_init_refs]
  end

  def use_init_refs?
    use_init_refs.to_i > 0
  end

  def use_init_refs=(val)
    merge_extra_info(use_init_refs: val)
  end

  def fetch_by_web_hook
    extra_info && extra_info[:fetch_by_web_hook]
  end

  def fetch_by_web_hook?
    fetch_by_web_hook.to_i > 0
  end

  def fetch_by_web_hook=(val)
    merge_extra_info(fetch_by_web_hook: val)
  end

  # Parent DIR name for storing repo
  def parent_dir_name
    project.identifier
  end

  private

  def all_applicable_hooks
    hooks.by_position + project.hooks.global.by_position + GlobalHook.by_position
  end

  def apply_for_issue_by_changeset(hook, issue, changeset)
    hook.apply_for_issue(
      issue,
      user:  changeset.user,
      notes: ll(Setting.default_language, :text_changed_by_changeset_hook, changeset.full_text_tag(issue.project))
    ) do
      Redmine::Hook.call_hook(:model_changeset_scan_commit_for_issue_ids_pre_issue_update,
        { changeset: changeset, issue: issue, hook: hook })
    end
  end

  def clear_changesets
    super
    clear_extra_info_of_changesets
  end
end
