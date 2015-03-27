require 'redmine/scm/adapters/git_adapter'
require 'redmine/scm/adapters/undev_git_revision'

module Redmine::Scm::Adapters
  class UndevGitAdapter < AbstractAdapter

    # Git executable name
    GIT_BIN = Redmine::Configuration['scm_git_command'] || "git"

    # default limit of commits for chunks
    cattr_accessor :default_chunk_size
    self.default_chunk_size = 150

    class GitBranch < Branch
      attr_accessor :is_default
    end

    class << self
      def client_command
        @@bin    ||= GIT_BIN
      end

      def sq_bin
        @@sq_bin ||= shell_quote_command
      end

      def client_version
        @@client_version ||= (scm_command_version || [])
      end

      def client_version_eq_or_higher?(ver)
        ver = ver.split('.').map(&:to_i)
        (client_version.slice(0, ver.length) <=> ver) >= 0
      end

      def client_available
        !client_version.empty?
      end

      def scm_command_version
        scm_version = scm_version_from_command_line.dup
        if scm_version.respond_to?(:force_encoding)
          scm_version.force_encoding('UTF-8')
        end
        if m = scm_version.match(%r{\A(.*?)((\d+\.)+\d+)})
          m[2].scan(%r{\d+}).collect(&:to_i)
        end
      end

      def scm_version_from_command_line
        shellout("#{sq_bin} --version --no-color") { |io| io.read }.to_s
      end
    end

    def initialize(url, root_url, login=nil, password=nil, path_encoding=nil)
      raise 'root_url must be provided' if root_url.blank?
      super
      @path_encoding = path_encoding.blank? ? 'UTF-8' : path_encoding
    end

    def path_encoding
      @path_encoding
    end

    def info
      Info.new(root_url: root_url, lastrev: lastrev('', nil))
    rescue
      nil
    end

    def branches
      return @branches if @branches
      @branches = []
      cmd_args = %w{branch --no-color --verbose --no-abbrev}
      git_cmd(cmd_args) do |io|
        io.each_line do |line|
          branch_rev = line.match('\s*(\*?)\s*(.*?)\s*([0-9a-f]{40}).*$')
          bran = GitBranch.new(branch_rev[2])
          bran.revision =  branch_rev[3]
          bran.scmid    =  branch_rev[3]
          bran.is_default = ( branch_rev[1] == '*' )
          @branches << bran
        end
      end
      @branches.sort!
    rescue ScmCommandAborted
      nil
    end

    def tags
      return @tags if @tags
      git_cmd('tag') do |io|
        @tags = io.readlines.sort!.map{|t| t.strip}
      end
    rescue ScmCommandAborted
      nil
    end

    def default_branch
      bras = self.branches
      return nil if bras.nil?
      default_bras = bras.select { |x| x.is_default == true }
      return default_bras.first.to_s unless default_bras.empty?
      master_bras = bras.select { |x| x.to_s == 'master' }
      master_bras.empty? ? bras.first.to_s : 'master'
    end

    def entry(path = nil, identifier = nil)
      parts = path.to_s.split(%r{[\/\\]}).select { |n| !n.blank? }
      search_path = parts[0..-2].join('/')
      search_name = parts[-1]
      if search_path.blank? && search_name.blank?
        # Root entry
        Entry.new(path: '', kind: 'dir')
      else
        # Search for the entry in the parent directory
        es = entries(search_path, identifier,
                     options = { report_last_commit: false })
        es ? es.detect {|e| e.name == search_name} : nil
      end
    end

    def entries(path, identifier = nil, options = {})
      path ||= ''
      p = scm_iconv(path_encoding, 'UTF-8', path)
      entries = Entries.new
      cmd_args = %w{ls-tree -l}
      cmd_args << "HEAD:#{p}"          if identifier.nil?
      cmd_args << "#{identifier}:#{p}" if identifier
      git_cmd(cmd_args) do |io|
        io.each_line do |line|
          e = line.chomp.to_s
          if e =~ /^\d+\s+(\w+)\s+([0-9a-f]{40})\s+([0-9-]+)\t(.+)$/
            type = $1
            sha  = $2
            size = $3
            name = $4
            if name.respond_to?(:force_encoding)
              name.force_encoding(path_encoding)
            end
            full_path = p.empty? ? name : "#{p}/#{name}"
            n      = scm_iconv('UTF-8', path_encoding, name)
            full_p = scm_iconv('UTF-8', path_encoding, full_path)
            entries << Entry.new({ name: n,
                    path:                full_p,
                    kind:                (type == 'tree') ? 'dir' : 'file',
                    size:                (type == 'tree') ? nil : size,
                    lastrev:             options[:report_last_commit] ?
                                             lastrev(full_path, identifier) : Revision.new
                                 }) unless entries.detect{|entry| entry.name == name}
          end
        end
      end
      entries.sort_by_name
    rescue ScmCommandAborted
      Redmine::Scm::Adapters::Entries.new
    end

    def lastrev(path, rev)
      return nil if path.nil?
      cmd_args = %w{log --no-color --encoding=UTF-8 --date=iso --pretty=fuller --no-merges -n 1}
      cmd_args << rev if rev
      cmd_args << '--' << path unless path.empty?
      lines = []
      git_cmd(cmd_args) { |io| lines = io.readlines }
      begin
        id = lines[0].split[1]
        author = lines[1].match('Author:\s+(.*)$')[1]
        time = Time.parse(lines[4].match('CommitDate:\s+(.*)$')[1])

        Revision.new({
                identifier: id,
                scmid:      id,
                author:     author,
                time:       time,
                message:    nil,
                paths:      nil
                     })
      rescue NoMethodError => e
        logger.error("The revision '#{path}' has a wrong format")
        return nil
      end
    rescue ScmCommandAborted
      nil
    end

    def diff(path, identifier_from, identifier_to = nil)
      path ||= ''
      cmd_args = []
      if identifier_to
        cmd_args << 'diff' << '--no-color' <<  identifier_to << identifier_from
      else
        cmd_args << 'show' << '--no-color' << identifier_from
      end
      cmd_args << '--' <<  scm_iconv(path_encoding, 'UTF-8', path) unless path.empty?
      diff = []
      git_cmd(cmd_args) do |io|
        io.each_line do |line|
          diff << line
        end
      end
      diff
    rescue ScmCommandAborted
      nil
    end

    def annotate(path, identifier = nil)
      identifier = 'HEAD' if identifier.blank?
      cmd_args = %w{blame --encoding=UTF-8}
      cmd_args << '-p' << identifier << '--' << scm_iconv(path_encoding, 'UTF-8', path)
      blame = Annotate.new
      content = nil
      git_cmd(cmd_args) { |io| io.binmode; content = io.read }
      # git annotates binary files
      return nil if content.is_binary_data?
      identifier = ''
      # git shows commit author on the first occurrence only
      authors_by_commit = {}
      content.split("\n").each do |line|
        if line =~ /^([0-9a-f]{39,40})\s.*/
          identifier = $1
        elsif line =~ /^author (.+)/
          authors_by_commit[identifier] = $1.strip
        elsif line =~ /^\t(.*)/
          blame.add_line($1, Revision.new(
              identifier: identifier,
              revision: identifier,
              scmid: identifier,
              author: authors_by_commit[identifier]
          ))
          identifier = ''
          author = ''
        end
      end
      blame
    rescue ScmCommandAborted
      nil
    end

    def cat(path, identifier=nil)
      if identifier.nil?
        identifier = 'HEAD'
      end
      cmd_args = %w|show --no-color|
      cmd_args << "#{identifier}:#{scm_iconv(@path_encoding, 'UTF-8', path)}"
      cat = nil
      git_cmd(cmd_args) do |io|
        io.binmode
        cat = io.read
      end
      cat
    rescue ScmCommandAborted
      nil
    end

    # if block is given then revisions will reading by chunks and
    # block will yields with hashed chunks (Redmine::Scm::Adapters::UndevGitRevision)
    # otherwise simply array of revisions will be returned
    # Note: With :reverse option method may only be called without block
    def revisions(path, identifier_from, identifier_to, options = {}, &block)
      if block_given?
        raise 'Can''t read chunks with reverse option' if options[:reverse]
        revisions_in_chunks(path, identifier_from, identifier_to, options, &block)
      else
        revs = []
        revisions_in_chunks(path, identifier_from, identifier_to, options) do |chunk|
          revs += chunk.values
        end
        options[:reverse] ? revs.reverse : revs
      end
    rescue ScmCommandAborted => e
      err_msg = "git log error: #{e.message}"
      logger.error(err_msg)
      if block_given?
        raise CommandFailed, err_msg
      else
        revs
      end
    end

    def revisions_in_chunks(path, identifier_from, identifier_to, options = {}, &block)

      revision_regexp = %r{
            (?<h>[0-9a-f]{40});\s
            (?<ai>.*);\s
            (?<d>.*);\s
            (?<p>.*);\s
            (?<cn>.*);\s
            (?<ce>.*);\s
            (?<ci>.*);\s
            (?<ai>.*)$
          }x

      # wee need to drag branches from head to parent commits
      # but git log will be read by block,
      # then we need to store boundary info between blocks
      boundary_drags = nil

      options.merge!(
          format: '%H; %ai; %d; %P; %cn; %ce; %ci; %ai%n%s%n%b%n%h',
          identifier_from: identifier_from,
          identifier_to: identifier_to)

      if self.class.client_version_eq_or_higher?('1.7.2')
        options[:format] = '%H; %ai; %d; %P; %cn; %ce; %ci; %ai%n%B%h'
      end

      chunked_git_log(path, options) do |git_log, git_patch_ids|

        chunk, refs = UndevGitRevisions.new(), []
        revision, wait_for = nil
        patch_ids_map = {}

        git_patch_ids.each_line do |line|
          m = line.split(' ')
          patch_ids_map[m[1]] = m[0]
        end

        git_log.each_line do |line|
          if md = line.match(revision_regexp)
            branches = extract_branches(md[:d])
            ctime = Time.parse(md[:ci]) unless md[:ci].blank?
            atime = Time.parse(md[:ai]) unless md[:ai].blank?
            parents = md[:p].blank? ? [] : md[:p].split(' ')

            revision = UndevGitRevision.new({
                    identifier:  md[:h],
                    scmid:       md[:h],
                    author:      "#{md[:cn]} <#{md[:ce]}>",
                    time:        ctime,
                    authored_on: atime,
                    message:     '',
                    paths:       [],
                    patch_id:    patch_ids_map[md[:h]],
                    parents:     parents,
                    branches:    branches,
                    branch:      branches.first })

            chunk[revision.identifier] = revision

            # store commits with branches to drag them to their parents later
            refs << revision if branches.any?

            # message starts on next line
            wait_for = :message
          else
            # suppress empty trailing lines
            next unless revision

            # looking for divider between message and paths (it's a hash abbr)
            if line.present? && revision.identifier.index(line.chomp) == 0
              wait_for = :path
              next
            end

            case wait_for
              when :message
                revision.message << "\n" unless revision.message.blank?
                revision.message << line.chomp
              when :path
                if line.present? && line =~ /\A(\w+)\s(.+)$/
                  revision.paths << { action: $1, path: $2 }
                end
            end
          end
        end

        # first, apply boundary drags from previous block if any
        chunk.apply_delayed_drags!(boundary_drags) if boundary_drags

        # drag branches for every commits in the block
        refs.each do |rev|
          chunk.drag_branches_to_parents!(rev)
        end

        # store operations to missed commits for the next block
        boundary_drags = chunk.delayed_drags

        block.call(chunk)
      end
    end

    def fetch!
      args = %w{fetch origin --force}
      git_cmd(args)
    end

    def cloned?
      return false unless Dir.exists?(root_url)

      args = ['--git-dir', root_url, 'rev-parse']
      args = args.map { |arg| shell_quote(arg.to_s) }.join(' ')
      cmd = [self.class.sq_bin, args].join(' ')

      shellout(cmd)

      $?.exitstatus == 0
    rescue CommandFailed
      false
    end

    def clone_repository
      FileUtils.mkdir_p(root_url)

      args = ['clone', url, root_url, '--mirror', '--quiet']
      args = args.map { |arg| shell_quote(arg.to_s) }.join(' ')
      cmd = [self.class.sq_bin, args].join(' ')

      shellout(cmd)

      if $? && $?.exitstatus != 0
        raise ScmCommandAborted, "can't clone repository git exited with non-zero status: #{$?.exitstatus}"
      end
    end

    private

    # execute git command and yield block for every chunk
    # chunk size gets from options[:chunk_size]
    def chunked_git_log(path, options, &block)
      skip = 0

      revisions = revisions_for_git_cmd(options)

      chunk_size = options[:chunk_size] || default_chunk_size

      while true

        if options[:limit]
          chunk_size = [options[:limit] - skip, chunk_size].min
        end

        cmd_args = %w{log --date=iso --date-order --name-status --no-color}
        cmd_args << "--format=#{options[:format]}"

        cmd_args << '--all' if revisions.empty? && options[:all]
        cmd_args << "--encoding=#{path_encoding}"
        cmd_args << "--skip=#{skip}" << "--max-count=#{chunk_size}"
        cmd_args << '--stdin'

        if path && !path.empty?
          cmd_args << '--' << scm_iconv(path_encoding, 'UTF-8', path)
        end

        git_log = nil
        git_cmd(cmd_args, { write_stdin: true }) do |io|
          io.binmode
          io.puts(revisions.join("\n"))
          io.close_write
          git_log = io.read.force_encoding(path_encoding)
        end

        begin
          return nil if git_log.blank?

        rescue ArgumentError #invalid byte sequence in UTF-8
          git_log = remove_invalid_characters(git_log)
        end

        # get patch_ids for commits

        git_patch_ids = patch_ids(path, revisions, chunk_size, skip)

        block.call(git_log, git_patch_ids)

        skip += chunk_size
      end
    end

    def remove_invalid_characters(s)
      s.chars.select { |c| c.valid_encoding? }.join
    end

    # get patch_ids for commits
    def patch_ids(path, revisions, limit, skip)
      git_patch_ids = ''
      git_cmd(%w{patch-id}, { write_stdin: true }) do |io_patch_id|
        io_patch_id.binmode

        cmd_args = %w{log -p --no-color --date-order --format=%H}
        cmd_args << '--all' if revisions.empty?
        cmd_args << "--encoding=#{path_encoding}"
        cmd_args << "--skip=#{skip}" << "--max-count=#{limit}"
        cmd_args << '--stdin'

        if path && !path.empty?
          cmd_args << '--' << scm_iconv(path_encoding, 'UTF-8', path)
        end

        git_cmd(cmd_args, { write_stdin: true }) do |io_log|
          io_log.binmode
          io_log.puts(revisions.join("\n"))
          io_log.close_write
          IO.copy_stream(io_log, io_patch_id)
        end

        io_patch_id.close_write
        git_patch_ids = io_patch_id.read.force_encoding(path_encoding)
      end
      git_patch_ids
    end

    def revisions_for_git_cmd(options = {})
      revisions = []
      identifier_from, identifier_to = options[:identifier_from], options[:identifier_to]
      if identifier_from || identifier_to
        revisions << ''
        revisions[0] << "#{identifier_from}.." if identifier_from
        revisions[0] << "#{identifier_to}" if identifier_to
      else
        unless options[:includes].blank?
          revisions += options[:includes]
        end
        unless options[:excludes].blank?
          revisions += options[:excludes].map{|r| "^#{r}"}
        end
      end
      revisions
    end

    # extract branches from git log format: (HEAD, master)
    # reject tags from branches
    def extract_branches(decorate, remove_head = true)
      return [] if decorate.blank?
      decorate.strip[1...-1].split(', ').
          reject { |b| remove_head && b == 'HEAD' || b =~ /^tag:\s/ }
    end

    def git_cmd(args, options = {}, &block)
      system_args = ['--git-dir', root_url]
      if self.class.client_version_above?([1, 7, 2])
        system_args << '-c' << 'core.quotepath=false'
      end

      args = system_args + Array.wrap(args)
      args = args.map { |arg| shell_quote(arg.to_s) }.join(' ')
      cmd = [self.class.sq_bin, args].join(' ')

      ret = shellout(cmd, options, &block)

      if $? && $?.exitstatus != 0
        raise ScmCommandAborted, "git exited with non-zero status: #{$?.exitstatus}"
      end
      ret
    end
  end
end
