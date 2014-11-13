module RedmineUndevGit::Services
  class CommandFailed < ServiceError
  end

  GitBranchRef = Struct.new(:name, :revision)

  class GitAdapter

    attr_reader :url, :root_url, :path_encoding

    class << self

      def git_version_above_or_equal?(v)
        (git_version <=> v) >= 0
      end

      def git_version
        @git_version ||= begin
          @git_version = shell_read("#{quoted_git_command} --version --no-color")
          @git_version.force_encoding('UTF-8') if @git_version.respond_to?(:force_encoding)
          if m = @git_version.match(%r{\A(.*?)((\d+\.)+\d+)})
            m[2].scan(%r{\d+}).collect(&:to_i)
          end
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
        msg = strip_credential(e.message)
        # The command failed, log it and re-raise
        logmsg = "GIT command failed, "
        logmsg += "make sure that git is in PATH (#{ENV['PATH']})\n"
        logmsg += "You can configure scm_git_command in config/configuration.yml.\n"
        logmsg += "#{strip_credential(cmd)}\n"
        logmsg += "with: #{msg}"
        Rails.logger.error(logmsg)
        raise CommandFailed, msg
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

    def branches
      result = []
      git('branch', '--no-color', '--verbose', '--no-abbrev') do |io|
        io.each_line do |line|
          if branch_rev = line.match('^\s*(\*?)\s*(.*?)\s*([0-9a-f]{40}).*$')
            result << GitBranchRef.new(branch_rev[2], branch_rev[3])
          end
        end
      end
      result
    end

    def git(*args, &block)
      options = args.extract_options!
      system_args = ['--git-dir', root_url]
      if self.class.git_version_above_or_equal?([1, 7, 2])
        system_args << '-c' << 'core.quotepath=false'
      end

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
