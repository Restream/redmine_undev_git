namespace :test do
  namespace :scm do
    namespace :setup do
      desc 'Creates a test git repository for undev_git'
      task :undev_git => :create_dir do
        extract_repo('undev_git_repository')
        extract_repo('rebase_test_before.git')
        extract_repo('rebase_test_after.git')
        extract_repo('hooks_every_branch_r1')
        extract_repo('hooks_every_branch_r2')
        extract_repo('hooks_every_branch_r3')
        extract_repo('hooks_every_branch_r4')
      end

      private

      def extract_repo(repo_name)
        source_tar = File.expand_path(
            File.join('..', '..', '..', 'test', 'fixtures', "#{repo_name}.tar.gz"), __FILE__)
        dest_dir = File.expand_path(
            File.join('..', '..', '..', '..', '..', 'tmp', 'test'), __FILE__)
        dest_repo_dir = File.join(dest_dir, repo_name)
        unless Dir.exists?(dest_repo_dir)
          system "tar -xvz -C #{dest_dir} -f #{source_tar}"
        end
      end
    end
  end
end
