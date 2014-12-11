require 'fileutils'

module RedmineUndevGit::Services
  class CommandFailed < ServiceError
  end

  GitBranchRef = Struct.new(:name, :sha)
  GitRevision = Struct.new(:sha, :aname, :aemail, :adate, :cname, :cemail, :cdate, :message)

  class GitAdapter

    attr_reader :url, :root_url, :path_encoding

    class << self

      def git_version
        result = shell_read("#{quoted_git_command} --version --no-color")
        result.force_encoding('UTF-8') if result.respond_to?(:force_encoding)
        if m = result.match(%r{\A(.*?)((\d+\.)+\d+)})
          m[2]
        else
          raise ServiceError, 'fails while check git version'
        end
      end

      def quoted_git_command
        @quoted_git_command ||= shell_quote(Redmine::Configuration['scm_git_command'] || 'git')
      end

      def shell_quote(str)
        if Redmine::Platform.mswin?
          '"' + str.gsub(/"/, '\\"') + '"'
        else
          "'" + str.gsub(/'/, "'\"'\"'") + "'"
        end
      end

      def shell_read(cmd, options = {})
        Rails.logger.debug 'called shell_read'
        shell_out(cmd, options) { |io| io.read }.to_s
      end

      def shell_out(cmd, options = {}, &block)
        mode = 'r+'
        IO.popen(cmd, mode) do |io|
          io.set_encoding('ASCII-8BIT') if io.respond_to?(:set_encoding)
          io.close_write unless options[:write_stdin]
          block.call(io) if block_given?
        end
      rescue Exception => e
        # The command failed, log it and re-raise
        logmsg = "#{cmd}\nfailed with: #{e.message}"
        Rails.logger.error(logmsg)
        raise CommandFailed, e.message
      end

    end

    # Instance methods

    def initialize(url, root_url, options = {})
      raise(ServiceError, 'root_url must be provided') if root_url.blank?
      @url = url
      @root_url = root_url
      @path_encoding = options[:path_encoding].blank? ? 'UTF-8' : options[:path_encoding]
    end

    def repository_exists?
      return false unless Dir.exists?(root_url)
      git('--git-dir', root_url, 'rev-parse')
      true
    rescue CommandFailed
      false
    end

    def clone_repository
      FileUtils.mkdir_p(root_url)
      git('clone', url, root_url, '--mirror', '--quiet')
    end

    def fetch!
      git('fetch', 'origin', '--force')
    end

    def branches(sha = nil)
      result = []
      args = %w{branch --no-color --verbose --no-abbrev}
      args += ['--contains', sha] if sha.present?
      git(*args) do |io|
        io.each_line do |line|
          if branch_rev = line.match('^\s*(\*?)\s*(.*?)\s*([0-9a-f]{40}).*$')
            result << GitBranchRef.new(branch_rev[2], branch_rev[3])
          end
        end
      end
      result
    end

    def revisions(include_revs = nil, exclude_revs = nil, options = {})

      # :sha              %H
      # :author           %an %ae
      # :author_date      %ai
      # :committer        %cn %ce
      # :committer_date   %ci
      # :message          %B

      revision_regexp = /(?<h>[0-9a-f]{40});\s(?<an>.*?);\s(?<ae>.*?);\s(?<ai>.*?);\s(?<cn>.*?);\s(?<ce>.*?);\s(?<ci>.*?);/

      format_string = '%H; %an; %ae; %ai; %cn; %ce; %ci;%n%B%H'

      revs = []
      revs += include_revs unless include_revs.blank?
      revs += exclude_revs.map{|r| "^#{r}"} unless exclude_revs.blank?

      cmd_args = %w{log --date=iso --date-order --reverse --name-status --no-color}
      cmd_args << "--format=\"#{format_string}\""
      cmd_args << '--all' if revs.empty?
      cmd_args << "--encoding=#{path_encoding}"

      grep_keywords = Array(options[:grep])
      if grep_keywords.any?
        grep_keywords.each do |keyword|
          cmd_args << "--grep=#{strip_special_characters(keyword)}"
        end
        cmd_args << '--regexp-ignore-case'
      end

      cmd_args << '--stdin'

      result = []

      git(*cmd_args, { write_stdin: true }) do |io|

        # includes and excludes
        io.binmode
        io.puts(revs.join("\n"))
        io.close_write

        revision = nil
        io.each_line do |io_line|
          line = io_line.dup
          line.force_encoding(path_encoding)
          begin
            line.blank?
          rescue ArgumentError #invalid byte sequence in UTF-8
            line = remove_invalid_characters(line)
          end

          if revision.nil? && md = line.match(revision_regexp)
            revision = GitRevision.new
            result << revision

            revision.message = ''
            revision.sha = md[:h]

            # author
            revision.aname = md[:an]
            revision.aemail = md[:ae]
            revision.adate = Time.parse(md[:ai]) unless md[:ai].blank?

            # committer
            revision.cname = md[:cn]
            revision.cemail = md[:ce]
            revision.cdate = Time.parse(md[:ci]) unless md[:ci].blank?

          elsif revision
            if line =~ /#{revision.sha}/
              revision = nil
            else
              revision.message << line
            end
          end
        end
      end
      result
    end

    def strip_special_characters(string)
      pattern = /('|"|\.|\*|\/|\-|\\|\s|;)/
      string.gsub(pattern, '')
    end

    def remove_invalid_characters(s)
      s.chars.select { |c| c.valid_encoding? }.join
    end

    def fetch_url=(new_url)
      git('remote', 'set-url', 'origin', new_url)
    end

    def fetch_url
      result = git('remote', '-v') { |io| io.read }.to_s
      match = result.match(/origin\s+(?<url>.+?)\s+\(fetch\)/)
      match && match[:url]
    end

    def remove_repo
      FileUtils.rm_r(root_url) if Dir.exists?(root_url)
    end

    # expects many arguments, not one array or string
    # examples:
    #   git('log', '--all')     # ok
    #   git('log --all')        # error
    #   git(['log',  '--all'])  # error
    def git(*args, &block)
      options = args.extract_options!
      system_args = ['--git-dir', root_url, '-c', 'core.quotepath=false']

      args = system_args + Array.wrap(args)
      args = args.map { |arg| self.class.shell_quote(arg.to_s) }.join(' ')
      cmd = [self.class.quoted_git_command, args].join(' ')

      ret = self.class.shell_out(cmd, options, &block)

      if $? && $?.exitstatus != 0
        raise CommandFailed, "git exited with non-zero status: #{$?.exitstatus}"
      end
      ret
    end

  end
end
