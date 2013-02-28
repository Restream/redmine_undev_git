module RedmineUndevGit::Patches
  module RepositoriesHelperPatch
    extend ActiveSupport::Concern

    include RedmineUndevGit::Helpers::UndevGitHelper

    def undev_git_field_tags(form, repository)
      [
          undev_git_url_tag(form, repository),
          undev_git_extra_report_last_commit_tag(form, repository),
          undev_git_use_init_hooks_tag(form, repository)
      ].compact.join('<br />').html_safe
    end

    private

    def undev_git_url_tag(form, repository)
      content_tag('p', form.text_field(
          :url, :label => l(:field_path_to_repository),
          :size => 60, :required => true,
          :disabled => repository.persisted?))
    end

    def undev_git_extra_report_last_commit_tag(form, repository)
      content_tag('p', form.check_box(
          :extra_report_last_commit,
          :label => l(:label_git_report_last_commit)))
    end

    def undev_git_use_init_hooks_tag(form, repository)
      content_tag('p', form.check_box(
          :use_init_hooks,
          :disabled => repository.persisted?,
          :label => :field_use_init_hooks))
    end
  end
end

unless RepositoriesHelper.included_modules.include?(RedmineUndevGit::Patches::RepositoriesHelperPatch)
  RepositoriesHelper.send :include, RedmineUndevGit::Patches::RepositoriesHelperPatch
end
