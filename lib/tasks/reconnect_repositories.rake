namespace :undev do
  desc "Reconnecting UndevGit repositories"
  task :reconnect_repositories => :environment do
    migration = RedmineUndevGit::Service::Migration
    Repository::UndevGit.find_each do |old_repo|
      begin
        puts "==> Reconnecting #{old_repo.url}"
        new_repo = migration.reconnect_repo_as_undev_git_to(old_repo, old_repo.project)
        puts "\t--> Clonning and fetching..."
        new_repo.fetch_changesets
      rescue => error
        puts "\t--> Skipping (#{error.message})"
      end
    end
    puts "==> Done."
  end
end
