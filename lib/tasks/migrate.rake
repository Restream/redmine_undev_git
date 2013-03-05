namespace :undev do
  desc "Migrates all Git repos to UndevGit"
  task :migrate_to_undev_git => :environment do
    migration = RedmineUndevGit::Service::Migration
    Repository::Git.find_each do |old_repo|
      begin
        puts "==> migrating #{old_repo.url}"
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
