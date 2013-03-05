namespace :undev do
  desc "Migrates all Git && UndevGit repositories to root UndevGit repositories from subprojects"
  task :migrate_from_subprojects_to_undev_git => :environment do
    migration = RedmineUndevGit::Service::Migration

    Project.find_each(:conditions => {:parent_id => nil}) do |root|
      descendants = root.descendants
      des_repos = descendants.map { |p| p.repositories }.flatten.compact
      des_repos.each do |descendant_repo|
        begin
          puts "==> migrating #{descendant_repo.url} from #{descendant_repo.project.identifier} to #{root.identifier}"
          new_repo = migration.reconnect_repo_as_undev_git_to(descendant_repo, root)
          puts "\t--> Clonning and fetching..."
          new_repo.fetch_changesets
        rescue
          puts "\t--> Skipping (#{error.message})"
        end
      end
    end
    puts "==> Done."
  end
end
