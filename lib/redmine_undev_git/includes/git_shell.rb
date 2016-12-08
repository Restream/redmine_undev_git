module RedmineUndevGit::Includes::GitShell
  extend ActiveSupport::Concern

  module ClassMethods

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

    def shell_out(cmd, &block)
      exit_status = nil
      errors = nil
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        stdin.set_encoding('ASCII-8BIT') if stdin.respond_to?(:set_encoding)
        stdout.set_encoding('ASCII-8BIT') if stdin.respond_to?(:set_encoding)
        block.call(stdin, stdout) if block_given?
        errors = stderr.read
        exit_status = wait_thr.value
      end
      [exit_status, errors]
    rescue Exception => e
      # The command failed, log it and re-raise
      logmsg = "#{cmd}\nfailed with: #{e.message}"
      Rails.logger.error(logmsg)
      raise Redmine::Scm::Adapters::CommandFailed, e.message
    end

    def shell_read(*args)
      result = nil
      exit_status, errors = shell_out(*args) { |_, stdout| result = stdout.read }
      return Redmine::Scm::Adapters::CommandFailed, errors unless exit_status == 0
      result
    end

  end

  def shell_out(cmd, &block)
    self.class.shell_out(cmd, &block)
  end

  # expects many arguments, not one array or string
  # examples:
  #   git_cmd('log', '--all')     # ok
  #   git_cmd('log --all')        # error
  #   git_cmd(['log',  '--all'])  # error
  #   block will be yielded with two arguments - stdin, stdout
  def git_cmd(*args, &block)
    system_args = ['--git-dir', root_url, '-c', 'core.quotepath=false']
    args = (system_args + Array(args)).flatten
    args = args.map { |arg| self.class.shell_quote(arg.to_s) }.join(' ')
    cmd  = [self.class.quoted_git_command, args].join(' ')

    exit_status, errors = self.class.shell_out(cmd, &block)

    raise Redmine::Scm::Adapters::CommandFailed, errors unless exit_status == 0
  end

  def git_read(*args)
    result = nil
    git_cmd(*args) { |_, stdout| result = stdout.read }
    result
  end

  def git_binread(*args)
    result = nil
    git_cmd(*args) do |_, stdout|
      stdout.binmode
      result = stdout.read
    end
    result
  end

  def git_readlines(*args)
    result = nil
    git_cmd(*args) { |_, stdout| result = stdout.readlines }
    result
  end

end
