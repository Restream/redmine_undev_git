namespace :undev do
  desc 'Migrates Git repos to UndevGit. Provide mapping file with "old_url;new_url" content as argument.'
  task :migrate_to_undev_git, [:mapping_filename] => [:environment] do |t, args|

    mfile = args[:mapping_filename]

    raise 'Provide mapping file with "old_url;new_url" content as argument.' unless mfile && File.exists?(mfile)

    migration = RedmineUndevGit::Services::Migration.new(mfile)
    migration.run_migration
  end

  desc 'Prepare full mapping for migration'
  task :migrate_to_undev_git_mappings, [:url_mapping_filename] => [:environment] do |t, args|
    mfile = args[:url_mapping_filename]

    raise 'Provide mapping url file with "old_url;new_url" content as argument.' unless mfile && File.exists?(mfile)

    migration = RedmineUndevGit::Services::Migration.new(mfile)
    mappings = migration.mappings.sort
    mappings.each do |m|
      old_modules = m.old_repo.project.module_enabled?('issue_tracking') ? '' :
          m.old_repo.project.enabled_module_names.join(', ')

      puts [
              m.old_repo.project.identifier,
              m.old_repo.url,
              m.old_repo.identifier,
              m.old_repo.is_default,
              old_modules,
              m.new_repo.project.identifier,
              m.new_repo.url,
              m.new_repo.identifier,
              m.new_repo.is_default,
              m.warnings.join(', ')
           ].join("\t")
    end
  end


  def repo_link(repo)
    "#{repo.url} /projects/#{repo.project.identifier}/settings/repositories"
  end
end
