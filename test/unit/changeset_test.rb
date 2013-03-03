require File.expand_path('../../test_helper', __FILE__)

class ChangesetTest < ActiveSupport::TestCase
  fixtures :projects, :repositories, :enabled_modules, :users, :roles

  def setup
    make_temp_dir
    Setting.enabled_scm << 'UndevGit'
    @project = Project.find(3)
    @repository = create_test_repository(:project => @project)
    @repository.fetch_changesets
  end

  def teardown
    remove_temp_dir
  end

  def test_parse_comment_for_issues
    changeset = @repository.find_changeset_by_name '2a68215'
    # 5, 13, 14 - issues in repository project
    samples = [
        {
            :comment => 'some text refs #10 and fixes #5,#13 and related to #14 @5h',
            :ref_keywords => 'refs, to',
            :fix_keywords => 'fixes',
            :cross_project_ref => false,
            :ref_issues => [5, 13, 14],
            :fix_issues => { 5 => %w{fixes}, 13 => %w{fixes} },
            :log_time => { 14 => %w{5h} }
        },
        {
            :comment => 'some text refs #10 and fixes #5,#13 and related to #14 @4h5m',
            :ref_keywords => 'refs, to',
            :fix_keywords => 'fixes',
            :cross_project_ref => true,
            :ref_issues => [5, 10, 13, 14],
            :fix_issues => { 5 => %w{fixes}, 13 => %w{fixes} },
            :log_time => { 14 => %w{4h5m} }
        },
        {
            :comment => 'some text closes #10 and fixes #5,#13 and related to #14 @3m and later #14 @2h',
            :ref_keywords => '*',
            :fix_keywords => 'fixes, closes',
            :cross_project_ref => true,
            :ref_issues => [5, 10, 13, 14],
            :fix_issues => { 5 => %w{fixes}, 10 => %w{closes} , 13 => %w{fixes} },
            :log_time => { 14 => %w{3m 2h} }
        }
    ]
    samples.each do |sample|
      changeset.stubs(:comments).returns(sample[:comment])
      Setting.commit_cross_project_ref = sample[:cross_project_ref] ? '1' : '0'
      parsed = changeset.parse_comment_for_issues sample[:ref_keywords], sample[:fix_keywords]
      assert_not_nil parsed

      assert_equal sample[:ref_issues], parsed[:ref_issues].map(&:id).sort,
                   "parse_comment_for_issue_ids('#{sample[:ref_keywords]}', '#{sample[:fix_keywords]}') for '#{sample[:comment]}'"

      assert_not_nil parsed[:fix_issues]
      sample[:fix_issues].each do |issue_id, keywords|
        issue = Issue.find(issue_id)
        parsed_keywords = parsed[:fix_issues][issue]
        assert_not_nil parsed_keywords, "parse_comment_for_issue_ids did not found #{keywords} keywords for ##{issue.id} in '#{sample[:comment]}'"
        assert_equal keywords.sort, parsed_keywords.sort, "parse_comment_for_issue_ids did not match sample #{keywords} keywords for ##{issue.id} in '#{sample[:comment]}'"
      end

      assert_not_nil parsed[:log_time]
      sample[:log_time].each do |issue_id, log_time|
        issue = Issue.find(issue_id)
        parsed_log_time = parsed[:log_time][issue]
        assert_not_nil parsed_log_time, "parse_comment_for_issue_ids did not found log_time for ##{issue.id} in '#{sample[:comment]}'"
        assert_equal log_time, parsed_log_time, "parse_comment_for_issue_ids did not match sample log_time #{log_time} for ##{issue.id} in '#{sample[:comment]}'"
      end
    end
  end

end
