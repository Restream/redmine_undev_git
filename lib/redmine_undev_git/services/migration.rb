module RedmineUndevGit
  module Services

    class Repo < Hashie::Dash
      property :id
      property :project, required: true
      property :url
      property :identifier
      property :is_default

      def to_s
        [id, project.identifier, identifier, url].join(';')
      end
    end

    class Mapping
      attr_reader :old_repo, :new_repo, :warnings

      def initialize(old_repo, new_url, warnings)
        @old_repo, @warnings = old_repo, warnings
        @new_repo = create_new_repo(new_url)
      end

      private

      def create_new_repo(new_url)
        Repo.new(
            project: find_project,
            url: new_url,
            identifier: find_identifier(new_url)
        )
      end

      def find_project
        prj = old_repo.project
        while prj.module_enabled?('issue_tracking').nil? && prj.parent
          prj = prj.parent
        end
        prj
      end

      def find_identifier(new_url)
        return old_repo.identifier if old_repo.identifier.present?
        $1 if new_url =~ /\/([\w\d\-_]+)\.git$/
      end

      def <=>(b)
        [new_repo.project.identifier, new_repo.identifier].join <=>
            [b.new_repo.project.identifier, b.new_repo.identifier].join
      end
    end

    class Migration

      def initialize(url_mapping_file)
        @url_mapping_file = url_mapping_file
      end

      def mappings
        @mappings ||= create_mappings
      end

      def url_mappings
        @url_mappings ||= read_url_mappings
      end

      def run_migration
        mappings.each_with_index do |m, i|
          puts "#{i}/#{mappings.count} Processing #{m.old_repo}"

          if m.new_repo.url.blank?
            puts "\tnew_url is not found, skipping"
            next
          end

          if same_repo = Repository.find_by_url(m.new_repo.url)
            puts "\tnew_url already used in project #{same_repo.project.identifier}"
            next
          end

          old_repo = Repository::Git.find_by_id(m.old_repo.id)
          unless old_repo
            puts "\trepository not found. Already deleted?"
            next
          end

          begin
            puts "\tfetching changesets for old repository..."
            old_repo.fetch_changesets
          rescue Exception => e
            puts "\tcan't fetch changesets: #{e.class}: #{e.message}"
          end

          begin
            new_repo = nil
            ActiveRecord::Base.transaction do
              puts "\tBegin transaction..."

              m.new_repo.project.enable_module!('hooks')

              new_repo = Repository::UndevGit.new(
                  project: m.new_repo.project,
                  identifier: m.new_repo.identifier,
                  url: m.new_repo.url,
                  use_init_hooks: 0,
                  use_init_refs: 1
              )
              new_repo.merge_extra_info(
                  'extra_report_last_commit' => old_repo.report_last_commit
              )
              old_repo.destroy
              new_repo.save!
              puts "\tNew repository created #{m.new_repo}"
              puts "\tClonning..."
              puts "\tOk." if new_repo.scm.cloned?
            end
            puts "\tTransaction committed. Fetching changesets..."
            new_repo.fetch_changesets
            puts "\tDone. #{new_repo.changesets.count} changesets fetched."
          rescue Redmine::Scm::Adapters::CommandFailed => e
            puts "\tCommandFailed: #{e.message}"
          rescue Exception => e
            puts "\tError: unhandled exception #{e.class}: #{e.message}"
          end
        end
      end

      private

      def create_mappings
        new_urls = []
        Repository::Git.order(:id).all.map do |r|
          old_repo = Repo.new(
              id: r.id,
              project: r.project,
              url: r.url,
              identifier: r.identifier,
              is_default: r.is_default
          )
          new_url = url_mappings[old_repo.url]

          warnings = []
          warnings << 'new_url duplicated' if new_urls.include?(new_url)
          warnings << 'new_url is blank' if new_url.blank?

          new_urls << new_url unless new_url.blank?

          Mapping.new(old_repo, new_url, warnings)
        end
      end

      def read_url_mappings
        maps = {}

        File.open(@url_mapping_file, 'r') do |mapfile|
          mapfile.each do |line|
            old_url, new_url = *(line.split(';').map(&:strip))
            maps[old_url] = new_url if old_url.present? && new_url.present?
          end
        end
        maps
      end

    end
  end
end
