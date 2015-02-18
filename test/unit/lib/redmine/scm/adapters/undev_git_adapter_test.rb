require File.expand_path('../../../../../../test_helper', __FILE__)
require 'mocha'

class UndevGitAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = File.join(Rails.root, 'tmp', 'test', 'undev_git_repository')

  FELIX_HEX  = "Felix Sch\xC3\xA4fer"
  CHAR_1_HEX = "\xc3\x9c"

  ## Git accepts only binary path in command line parameter.
  ## So, there is no way to use binary command line parameter in JRuby.
  JRUBY_SKIP     = (RUBY_PLATFORM == 'java')
  JRUBY_SKIP_STR = "TODO: This test fails in JRuby"

  if File.directory?(REPOSITORY_PATH)
    ## Ruby uses ANSI api to fork a process on Windows.
    ## Japanese Shift_JIS and Traditional Chinese Big5 have 0x5c(backslash) problem
    ## and these are incompatible with ASCII.
    ## Git for Windows (msysGit) changed internal API from ANSI to Unicode in 1.7.10
    ## http://code.google.com/p/msysgit/issues/detail?id=80
    ## So, Latin-1 path tests fail on Japanese Windows
    WINDOWS_PASS = (Redmine::Platform.mswin? &&
                    Redmine::Scm::Adapters::UndevGitAdapter.client_version_above?([1, 7, 10]))
    WINDOWS_SKIP_STR = "TODO: This test fails in Git for Windows above 1.7.10"
    TAG_PASS = Redmine::Scm::Adapters::UndevGitAdapter.client_version_above?([1, 8, 1])

    def setup
      @temp_storage_dir = Dir.mktmpdir('repo')
      Redmine::Scm::Adapters::UndevGitAdapter.default_chunk_size = 5
      adapter_class = Redmine::Scm::Adapters::UndevGitAdapter
      assert adapter_class
      assert adapter_class.client_command
      assert adapter_class.client_available
      assert adapter_class.client_version_above?([1])
      assert adapter_class.client_version_above?([1, 0])

      @adapter = Redmine::Scm::Adapters::UndevGitAdapter.new(
                    REPOSITORY_PATH,
                    get_temp_dir,
                    nil,
                    nil,
                    'ISO-8859-1'
                    #'UTF-8'
                 )
      assert @adapter
      @adapter.clone_repository
      @char_1 = CHAR_1_HEX.dup
      if @char_1.respond_to?(:force_encoding)
        @char_1.force_encoding('UTF-8')
      end
    end

    def teardown
      FileUtils.remove_entry_secure(@temp_storage_dir)
    end

    def test_scm_version
      to_test = { "git version 1.7.3.4\n"             => [1,7,3,4],
                  "1.6.1\n1.7\n1.8"                   => [1,6,1],
                  "1.6.2\r\n1.8.1\r\n1.9.1"           => [1,6,2]}
      to_test.each do |s, v|
        test_scm_version_for(s, v)
      end
    end

    def test_branches
      brs = []
      @adapter.branches.each do |b|
        brs << b
      end
      assert_equal 6, brs.length
      br_issue_8857 = brs[0]
      assert_equal 'issue-8857', br_issue_8857.to_s
      assert_equal '2a682156a3b6e77a8bf9cd4590e8db757f3c6c78', br_issue_8857.revision
      assert_equal br_issue_8857.scmid, br_issue_8857.revision
      br_latin_1_path = brs[1]
      assert_equal 'latin-1-path-encoding', br_latin_1_path.to_s
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', br_latin_1_path.revision
      assert_equal br_latin_1_path.scmid, br_latin_1_path.revision
      br_master = brs[2]
      assert_equal 'master', br_master.to_s
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', br_master.revision
      assert_equal br_master.scmid, br_master.revision
      br_master_20120212 = brs[3]
      assert_equal 'master-20120212', br_master_20120212.to_s
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', br_master_20120212.revision
      assert_equal br_master_20120212.scmid, br_master_20120212.revision
      br_latin_1 = brs[-2]
      assert_equal 'test-latin-1', br_latin_1.to_s
      assert_equal '67e7792ce20ccae2e4bb73eed09bb397819c8834', br_latin_1.revision
      assert_equal br_latin_1.scmid, br_latin_1.revision
      br_test = brs[-1]
      assert_equal 'test_branch', br_test.to_s
      assert_equal 'fba357b886984ee71185ad2065e65fc0417d9b92', br_test.revision
      assert_equal br_test.scmid, br_test.revision
    end

    def test_tags
      assert_equal %w{tag00.lightweight tag01.annotated}, @adapter.tags
    end

    def test_revisions_master_all
      revs1 = @adapter.revisions('', nil, 'master',{})
      assert_equal 15, revs1.length
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[ 0].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[-1].identifier

      revs2 = @adapter.revisions('', nil, "master", { reverse: true })
      assert_equal 15, revs2.length
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs2[-1].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs2[ 0].identifier
    end

    def test_revisions_master_merged_rev
      revs1 = @adapter.revisions('', "713f4944648826f558cf548222f813dabe7cbb04",
                                 "master", { reverse: true })
      assert_equal 8, revs1.length
      assert_equal 'fba357b886984ee71185ad2065e65fc0417d9b92', revs1[ 0].identifier
      assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs1[ 1].identifier
      # 4a07fe31b is not a child of 713f49446
      assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs1[ 2].identifier
      # Merged revision
      assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs1[ 3].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[-1].identifier

      revs2 = @adapter.revisions('', "fba357b886984ee71185ad2065e65fc0417d9b92",
                                 "master", { reverse: true })
      assert_equal 7, revs2.length
      assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs2[ 0].identifier
      # 4a07fe31b is not a child of fba357b8869
      assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs2[ 1].identifier
      # Merged revision
      assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs2[ 2].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs2[-1].identifier
    end

    def test_revisions_branch_latin_1_path_encoding_all
      revs1 = @adapter.revisions('', nil, "latin-1-path-encoding",{})
      assert_equal 8, revs1.length
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[ 0].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[-1].identifier

      revs2 = @adapter.revisions('', nil, "latin-1-path-encoding", { reverse: true })
      assert_equal 8, revs2.length
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs2[-1].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs2[ 0].identifier
    end

    def test_revisions_branch_latin_1_path_encoding_with_rev
      revs1 = @adapter.revisions('', '7234cb2750b63f47bff735edc50a1c0a433c2518',
                                 "latin-1-path-encoding", { reverse: true })
      assert_equal 7, revs1.length
      assert_equal '899a15dba03a3b350b89c3f537e4bbe02a03cdc9', revs1[ 0].identifier
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[-1].identifier

      revs2 = @adapter.revisions('', '57ca437c0acbbcb749821fdf3726a1367056d364',
                                 "latin-1-path-encoding",{ reverse: true })
      assert_equal 3, revs2.length
      assert_equal '4fc55c43bf3d3dc2efb66145365ddc17639ce81e', revs2[ 0].identifier
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs2[-1].identifier
    end

    def test_revisions_invalid_rev
      assert_equal [], @adapter.revisions('', '1234abcd', "master")
      assert_raise Redmine::Scm::Adapters::CommandFailed do
        revs = []
        @adapter.revisions('', '1234abcd', "master") do |chunk|
          revs += chunk
        end
      end
    end

    def test_revisions_includes_master_two_revs
      revs1 = @adapter.revisions('', nil, nil,
                         { reverse:    true,
                             includes: ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                             excludes: ['4f26664364207fa8b1af9f8722647ab2d4ac5d43'] })
      assert_equal 2, revs1.length
      assert_equal 'ed5bb786bbda2dee66a2d50faf51429dbc043a7b', revs1[ 0].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[-1].identifier
    end

    def test_revisions_includes_master_two_revs_from_origin
      revs1 = @adapter.revisions('', nil, nil,
                         { reverse:    true,
                             includes: ['899a15dba03a3b350b89c3f537e4bbe02a03cdc9'],
                             excludes: [] })
      assert_equal 2, revs1.length
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[ 0].identifier
      assert_equal '899a15dba03a3b350b89c3f537e4bbe02a03cdc9', revs1[ 1].identifier
    end

    def test_revisions_includes_merged_revs
      revs1 = @adapter.revisions('', nil, nil,
                         { reverse:    true,
                             includes: ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                             excludes: ['fba357b886984ee71185ad2065e65fc0417d9b92'] })
      assert_equal 7, revs1.length
      assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs1[ 0].identifier
      assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs1[ 1].identifier
      assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs1[ 2].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[-1].identifier
    end

    def test_revisions_includes_two_heads
      revs1 = @adapter.revisions('', nil, nil,
                         { reverse:    true,
                             includes: ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c',
                                 '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127'],
                             excludes: ['4f26664364207fa8b1af9f8722647ab2d4ac5d43',
                                 '4fc55c43bf3d3dc2efb66145365ddc17639ce81e'] })
      assert_equal 4, revs1.length
      assert_equal 'ed5bb786bbda2dee66a2d50faf51429dbc043a7b', revs1[ 0].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[ 1].identifier
      assert_equal '64f1f3e89ad1cb57976ff0ad99a107012ba3481d', revs1[-2].identifier
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[-1].identifier
    end

    def test_revisions_disjointed_histories_revisions
      revs1 = @adapter.revisions('', nil, nil,
                         { reverse:    true,
                             includes: ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c',
                                 '92397af84d22f27389c822848ecd5b463c181583'],
                             excludes: ['95488a44bc25f7d1f97d775a31359539ff333a63',
                                 '4f26664364207fa8b1af9f8722647ab2d4ac5d43'] })
      assert_equal 4, revs1.length
      assert_equal 'ed5bb786bbda2dee66a2d50faf51429dbc043a7b', revs1[ 0].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[ 1].identifier
      assert_equal 'bc201c95999c4f10d018b0aa03b541cd6a2ff0ee', revs1[-2].identifier
      assert_equal '92397af84d22f27389c822848ecd5b463c181583', revs1[-1].identifier
    end

    def test_revisions_invalid_rev_excludes
      assert_equal [], @adapter.revisions('', nil, nil,
                                          { reverse:    true,
                                              includes: ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                                              excludes: ['0123abcd4567'] })
      assert_raise Redmine::Scm::Adapters::CommandFailed do
        revs = []
        @adapter.revisions('', nil, nil,
                           { includes:   ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                               excludes: ['0123abcd4567'] }) do |chunk|
          revs += chunk
        end
      end
    end

    def test_getting_revisions_with_spaces_in_filename
      assert_equal 1, @adapter.revisions("filemane with spaces.txt",
                                         nil, "master").length
    end

    def test_parents
      revs1 = @adapter.revisions('', nil, "master", { reverse: true })
      assert_equal 15, revs1.length
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                   revs1[0].identifier
      assert_equal [], revs1[0].parents
      assert_equal "899a15dba03a3b350b89c3f537e4bbe02a03cdc9",
                   revs1[1].identifier
      assert_equal 1, revs1[1].parents.length
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                   revs1[1].parents[0]
      assert_equal "32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf",
                   revs1[10].identifier
      assert_equal 2, revs1[10].parents.length
      assert_equal "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8",
                   revs1[10].parents[0]
      assert_equal "7e61ac704deecde634b51e59daa8110435dcb3da",
                   revs1[10].parents[1]
    end

    def test_getting_revisions_with_leading_and_trailing_spaces_in_filename
      revisions = @adapter.revisions(" filename with a leading space.txt ", nil, "master")
      assert_equal 1, revisions.length
      assert_equal " filename with a leading space.txt ", revisions.first.paths[0][:path]
    end

    def test_getting_entries_with_leading_and_trailing_spaces_in_filename
      assert_equal " filename with a leading space.txt ",
         @adapter.entries('',
                 '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c')[3].name
    end

    def test_annotate
      annotate = @adapter.annotate('sources/watchers_controller.rb')
      assert_kind_of Redmine::Scm::Adapters::Annotate, annotate
      assert_equal 41, annotate.lines.size
      assert_equal "# This program is free software; you can redistribute it and/or",
                   annotate.lines[4].strip
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                    annotate.revisions[4].identifier
      assert_equal "jsmith", annotate.revisions[4].author
    end

    def test_annotate_moved_file
      annotate = @adapter.annotate('renamed_test.txt')
      assert_kind_of Redmine::Scm::Adapters::Annotate, annotate
      assert_equal 2, annotate.lines.size
    end

    def test_last_rev
      last_rev = @adapter.lastrev("README",
                                  "4f26664364207fa8b1af9f8722647ab2d4ac5d43")
      assert_equal "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8", last_rev.scmid
      assert_equal "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8", last_rev.identifier
      assert_equal "Adam Soltys <asoltys@gmail.com>", last_rev.author
      assert_equal "2009-06-24 05:27:38".to_time, last_rev.time
    end

    def test_last_rev_with_spaces_in_filename
      last_rev = @adapter.lastrev("filemane with spaces.txt",
                                  "ed5bb786bbda2dee66a2d50faf51429dbc043a7b")
      str_felix_hex  = FELIX_HEX.dup
      last_rev_author = last_rev.author
      if last_rev_author.respond_to?(:force_encoding)
        str_felix_hex.force_encoding('ASCII-8BIT')
      end
      assert_equal "ed5bb786bbda2dee66a2d50faf51429dbc043a7b", last_rev.scmid
      assert_equal "ed5bb786bbda2dee66a2d50faf51429dbc043a7b", last_rev.identifier
      assert_equal "#{str_felix_hex} <felix@fachschaften.org>",
                     last_rev.author
      assert_equal "2010-09-18 19:59:46".to_time, last_rev.time
    end

    def test_latin_1_path
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        p2 = "latin-1-dir/test-#{@char_1}-2.txt"
        ['4fc55c43bf3d3dc2efb66145365ddc17639ce81e', '4fc55c43bf3'].each do |r1|
          assert @adapter.diff(p2, r1)
          assert @adapter.cat(p2, r1)
          assert_equal 1, @adapter.annotate(p2, r1).lines.length
          ['64f1f3e89ad1cb57976ff0ad99a107012ba3481d', '64f1f3e89ad1cb5797'].each do |r2|
            assert @adapter.diff(p2, r1, r2)
          end
        end
      end
    end

    def test_entries_tag
      entries1 = @adapter.entries(nil, 'tag01.annotated',
                                  options = { report_last_commit: true })
      assert entries1
      assert_equal 3, entries1.size
      assert_equal 'sources', entries1[1].name
      assert_equal 'sources', entries1[1].path
      assert_equal 'dir', entries1[1].kind
      readme = entries1[2]
      assert_equal 'README', readme.name
      assert_equal 'README', readme.path
      assert_equal 'file', readme.kind
      assert_equal 27, readme.size
      assert_equal '899a15dba03a3b350b89c3f537e4bbe02a03cdc9', readme.lastrev.identifier
      assert_equal Time.gm(2007, 12, 14, 9, 24, 1), readme.lastrev.time
    end

    def test_entries_branch
      entries1 = @adapter.entries(nil, 'test_branch',
                                  options = { report_last_commit: true })
      assert entries1
      assert_equal 4, entries1.size
      assert_equal 'sources', entries1[1].name
      assert_equal 'sources', entries1[1].path
      assert_equal 'dir', entries1[1].kind
      readme = entries1[2]
      assert_equal 'README', readme.name
      assert_equal 'README', readme.path
      assert_equal 'file', readme.kind
      assert_equal 159, readme.size
      assert_equal '713f4944648826f558cf548222f813dabe7cbb04', readme.lastrev.identifier
      assert_equal Time.gm(2009, 6, 19, 4, 37, 23), readme.lastrev.time
    end

    def test_entries_wrong_path_encoding
      adpt = Redmine::Scm::Adapters::UndevGitAdapter.new(
                    REPOSITORY_PATH,
                    get_temp_dir,
                    nil,
                    nil,
                    'EUC-JP'
                 )
      adpt.clone_repository
      entries1 = adpt.entries('latin-1-dir', '64f1f3e8')
      assert entries1
      assert_equal 3, entries1.size
      f1 = entries1[1]
      assert_equal nil, f1.name
      assert_equal nil, f1.path
      assert_equal 'file', f1.kind
    end

    def test_entries_latin_1_files
      entries1 = @adapter.entries('latin-1-dir', '64f1f3e8')
      assert entries1
      assert_equal 3, entries1.size
      f1 = entries1[1]
      assert_equal "test-#{@char_1}-2.txt", f1.name
      assert_equal "latin-1-dir/test-#{@char_1}-2.txt", f1.path
      assert_equal 'file', f1.kind
    end

    def test_entries_latin_1_dir
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        entries1 = @adapter.entries("latin-1-dir/test-#{@char_1}-subdir",
                                    '1ca7f5ed')
        assert entries1
        assert_equal 3, entries1.size
        f1 = entries1[1]
        assert_equal "test-#{@char_1}-2.txt", f1.name
        assert_equal "latin-1-dir/test-#{@char_1}-subdir/test-#{@char_1}-2.txt", f1.path
        assert_equal 'file', f1.kind
      end
    end

    def test_entry
      entry = @adapter.entry()
      assert_equal "", entry.path
      assert_equal "dir", entry.kind
      entry = @adapter.entry('')
      assert_equal "", entry.path
      assert_equal "dir", entry.kind
      assert_nil @adapter.entry('invalid')
      assert_nil @adapter.entry('/invalid')
      assert_nil @adapter.entry('/invalid/')
      assert_nil @adapter.entry('invalid/invalid')
      assert_nil @adapter.entry('invalid/invalid/')
      assert_nil @adapter.entry('/invalid/invalid')
      assert_nil @adapter.entry('/invalid/invalid/')
      ["README", "/README"].each do |path|
        entry = @adapter.entry(path, '7234cb2750b63f')
        assert_equal "README", entry.path
        assert_equal "file", entry.kind
      end
      ["sources", "/sources", "/sources/"].each do |path|
        entry = @adapter.entry(path, '7234cb2750b63f')
        assert_equal "sources", entry.path
        assert_equal "dir", entry.kind
      end
      ["sources/watchers_controller.rb", "/sources/watchers_controller.rb"].each do |path|
        entry = @adapter.entry(path, '7234cb2750b63f')
        assert_equal "sources/watchers_controller.rb", entry.path
        assert_equal "file", entry.kind
      end
    end

    def test_path_encoding_default_utf8
      adpt1 = Redmine::Scm::Adapters::UndevGitAdapter.new(
                                REPOSITORY_PATH,
                                get_temp_dir
                              )
      assert_equal "UTF-8", adpt1.path_encoding
      adpt2 = Redmine::Scm::Adapters::UndevGitAdapter.new(
                                REPOSITORY_PATH,
                                get_temp_dir,
                                nil,
                                nil,
                                ""
                              )
      assert_equal "UTF-8", adpt2.path_encoding
    end

    def test_cat_path_invalid
      assert_nil @adapter.cat('invalid')
    end

    def test_cat_revision_invalid
      assert     @adapter.cat('README')
      assert_nil @adapter.cat('README', '1234abcd5678')
    end

    def test_diff_path_invalid
      assert_equal [], @adapter.diff('invalid', '713f4944648826f5')
    end

    def test_diff_revision_invalid
      assert_nil @adapter.diff(nil, '1234abcd5678')
      assert_nil @adapter.diff(nil, '713f4944648826f5', '1234abcd5678')
      assert_nil @adapter.diff(nil, '1234abcd5678', '713f4944648826f5')
    end

    def test_annotate_path_invalid
      assert_nil @adapter.annotate('invalid')
    end

    def test_annotate_revision_invalid
      assert     @adapter.annotate('README')
      assert_nil @adapter.annotate('README', '1234abcd5678')
    end

    def test_client_version_lower
      @adapter.class.expects(:client_version).returns([1,7,2])
      refute @adapter.class.client_version_eq_or_higher?('1.8')
    end

    def test_client_version_equal
      @adapter.class.expects(:client_version).returns([1,7,2])
      assert @adapter.class.client_version_eq_or_higher?('1.7')
    end

    def test_client_version_higher
      @adapter.class.expects(:client_version).returns([1,7,2])
      assert @adapter.class.client_version_eq_or_higher?('1.6')
    end

    def test_patch_ids
      adapt = Redmine::Scm::Adapters::UndevGitAdapter.new(
          R_BEFORE_REBASE_PATH,
          get_temp_dir,
          nil,
          nil,
          'UTF-8'
      )
      #repo = create_test_repository(url: R_BEFORE_REBASE_PATH,
      #                              path_encoding: 'UTF-8')
      patch_ids = {
        '2b91d81c6448716a5fcfef1292c45d6d7cfea3d6' => 'c7170bbd4448cbf3b34b99abd37dec3e1de16b8a',
        'ad445deb690a213ec8625c22e5e2bd4911c3e035' => '064976b3ad63557b9ab0b209bbca27978f593ef4',
        'd2815cbf826c451dfb1a9cd7a90dd9fda220efee' => '0e3edb88938668e3e2c5bb74f78eaa1efea5dbac',
        'b278ae21e9c85a1300dae2d1c995dfbf7ea0d859' => '720211a3c6cdc15a4a4314b6c870dc573c222003',
        '43784cc1dcf240442eaf06775b75212201dd5770' => '7d531ff563dfdf9861421c2b2a6e5b3eed5f5f63',
        '40a5965716b3c46e638ada5ddab6340e65b1c1b1' => '5c766d4796d44fad6ba8152c8a6220c4cdc2b4e7',
        '8455e27046da069ff7476c3ec8440e5c37a56cd6' => '0bdf90be6e1205b662d4a0424c564bed11f7945b',
        'ac7080c5e9fa6e1b49c7b2fcdf8f7dd23b31ed8a' => 'aaabff51c84c2d129ca270a2b2599ec253c30611',
        '21d88b7b22d1d65fb295bf80b498626c39b44a1a' => '3b55a4a49664e13cffc1408397e05d089d7097b3'
      }
      revs = adapt.revisions('', nil, nil)
      revs.each do |rev|
        patch_id = patch_ids[rev.scmid]
        assert patch_id
        assert_equal patch_id, rev.patch_id
      end
    end

    if TAG_PASS
      def test_ignore_tags_in_branches
        revs = @adapter.revisions('', nil, 'tag00.lightweight',{})
        assert_equal 1, revs.length
        assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs[0].identifier
        assert_equal [], revs[0].branches
      end
    end

    private

    def test_scm_version_for(scm_command_version, version)
      @adapter.class.expects(:scm_version_from_command_line).returns(scm_command_version)
      assert_equal version, @adapter.class.scm_command_version
    end

    def get_temp_dir
      @temp_dir_no ||= 0
      @temp_dir_no += 1
      File.join(@temp_storage_dir, @temp_dir_no.to_s)
    end

  else
    puts "Git test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
