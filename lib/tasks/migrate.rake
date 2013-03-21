namespace :undev do
  desc 'Migrates Git repos to UndevGit. Provide mapping file with "old_url;new_url" content as argument.'
  task :migrate_to_undev_git, [:mapping_filename] => [:environment] do |t, args|

    Setting.enabled_scm << 'UndevGit' unless Setting.enabled_scm.include? 'UndevGit'

    mfile = args[:mapping_filename]

    raise 'Provide mapping file with "old_url;new_url" content as argument.' unless mfile && File.exists?(mfile)

    File.open(mfile, 'r') do |mapfile|
      mapfile.each do |line|
        old_url, new_url = *(line.split(';').map(&:strip))
        next unless old_url.present? && new_url.present?

        if old_repo = Repository::Git.find_by_url(old_url)
          puts "found repo with url #{old_url} in project #{old_repo.project}"
          puts "\tmigrating to #{new_url}"

          if same_repo = Repository.find_by_url(new_url)
            puts "\tWarning! Repo with #{new_url} already created in project #{same_repo.project}"
            next
          end

          old_repo.fetch_changesets

          begin
            ActiveRecord::Base.transaction do

              project = old_repo.project
              project.enable_module!('hooks')

              new_repo = Repository::UndevGit.new(
                  :project => project,
                  :identifier => old_repo.identifier,
                  :is_default => old_repo.is_default,
                  :url => new_url,
                  :use_init_hooks => 0,
                  :use_init_refs => 1
              )
              new_repo.merge_extra_info(
                  'extra_report_last_commit' => old_repo.report_last_commit
              )
              old_repo.destroy
              new_repo.save!
              new_repo.fetch_changesets
            end
          rescue Redmine::Scm::Adapters::CommandFailed => e
            puts "\tCommandFailed: #{e.message}"
          end
        else
          if Repository::UndevGit.find_by_url(new_url)
            puts "- already migrated #{old_url} to #{new_url}"
          else
            puts "- not found repo with #{old_url} (#{new_url})"
          end
        end
      end
    end
  end

  desc 'Test migrate Git to UndevGit'
  task :test_migrate_to_undev_git, [:mapping_filename] => [:environment] do |t, args|
    mfile = args[:mapping_filename]

    raise 'Provide mapping file with "old_url;new_url" content as argument.' unless mfile && File.exists?(mfile)

    maps = {}

    File.open(mfile, 'r') do |mapfile|
      mapfile.each do |line|
        old_url, new_url = *(line.split(';').map(&:strip))
        maps[old_url] = new_url if old_url.present? && new_url.present?
      end
    end

    results = {}

    Repository::Git.find_each do |repo|
      if maps.has_key?(repo.url)
        if same_repo = Repository.find_by_url(maps[repo.url])
          results[:doubles] ||= []
          results[:doubles] << [repo, same_repo]
        else
          results[:ok] ||= []
          results[:ok] << [repo, maps[repo.url]]
        end
      else
        results[:not_found] ||= []
        results[:not_found] << [repo]
      end
    end
    if results.has_key? :ok
      puts "Ready to migrate repositories #{results[:ok].count} :"
      results[:ok].each do |row|
        puts [repo_link(row[0]), row[1]].join(' ')
      end
    end
    if results.has_key? :doubles
      puts "These repositories already created #{results[:doubles].count} :"
      results[:doubles].each do |row|
        puts [repo_link(row[0]), repo_link(row[1])].join(' ')
      end
    end
    if results.has_key? :not_found
      puts "Not found in mapping file #{results[:not_found].count} :"
      results[:not_found].each do |row|
        puts [repo_link(row[0])].join(' ')
      end
    end
  end

  def repo_link(repo)
    "#{repo.url} /projects/#{repo.project.identifier}/settings/repositories"
  end
end
