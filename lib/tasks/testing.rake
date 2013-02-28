namespace :test do
  namespace :scm do
    namespace :setup do
      desc 'Creates a test git repository for undev_git'
      task :undev_git => :create_dir do
        repo_path = File.expand_path(
            File.join('..','..','..','test','fixtures','undev_git_repository.tar.gz'),
            __FILE__)
        unless File.exists?('tmp/test/undev_git_repository')
          system "tar -xvz -C tmp/test -f #{repo_path}"
        end
      end
    end
  end
end
