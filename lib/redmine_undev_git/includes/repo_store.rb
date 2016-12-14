module RedmineUndevGit::Includes::RepoStore
  extend ActiveSupport::Concern

  included do
    # root_url stores path to local bare repository
    attr_protected :root_url

    # Storage folder for local copies of remote repositories
    cattr_accessor :repo_storage_dir
    self.repo_storage_dir = Redmine::Configuration['scm_repo_storage_dir'] || begin
      rpath = Rails.root.join('repos')
      rpath.symlink? ? File.readlink(rpath) : rpath
    end

    after_destroy :remove_repository_folder
  end

  def init_scm
    @scm = nil
  end

  def scm
    initialize_root_url
    super

    unless @scm.cloned?

      #try to clone twice
      begin
        @scm.clone_repository
      rescue Redmine::Scm::Adapters::CommandFailed
        @scm.clone_repository
      end
    end
    @scm
  end

  def initialize_root_url
    if root_url.blank?
      unless respond_to?(:parent_dir_name)
        raise 'You should define "parent_dir_name" when include RedmineUndevGit::Includes::RepoStore module'
      end
      root_url = File.join(self.repo_storage_dir, parent_dir_name, id.to_s)
      update_attribute(:root_url, root_url)
    end
  end

  def remove_repository_folder
    FileUtils.remove_entry_secure(root_url) if root_url.present? && Dir.exist?(root_url)
  end
end
