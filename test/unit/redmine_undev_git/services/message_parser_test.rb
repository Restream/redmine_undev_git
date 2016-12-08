require File.expand_path('../../../../test_helper', __FILE__)

class RedmineUndevGit::Services::MessageParserTest < ActiveSupport::TestCase

  def test_parse_message_for_references_with_keywords
    parser    = RedmineUndevGit::Services::MessageParser.new(%w{one two three}, [])
    issue_ids = parser.parse_message_for_references('one #1; two #2 four #4 three #3')
    assert_equal [1, 2, 3], issue_ids
  end

  def test_parse_message_for_references_returns_many_ids
    parser    = RedmineUndevGit::Services::MessageParser.new(%w{one}, [])
    issue_ids = parser.parse_message_for_references('one #1, #5,#654 #76&#49; two #2 four #4 three #3')
    assert_equal [1, 5, 654, 76, 49], issue_ids
  end

  def test_parse_message_for_references_returns_unique_ids
    parser    = RedmineUndevGit::Services::MessageParser.new(%w{one two three}, [])
    issue_ids = parser.parse_message_for_references('one #1, #2; two #2,#1 four #4 three #3,#3 and one #3')
    assert_equal [1, 2, 3], issue_ids
  end

  def test_parse_message_for_references_works_with_any_ref_keywords
    parser    = RedmineUndevGit::Services::MessageParser.new(nil, [])
    issue_ids = parser.parse_message_for_references('one #1, #2; two #2,#1 four #4 three #3,#3 and one #3')
    assert_equal [1, 2, 4, 3], issue_ids
  end

  def test_parse_message_for_logtime
    parser      = RedmineUndevGit::Services::MessageParser.new(nil, [])
    log_entries = parser.parse_message_for_logtime('one #1 two #2 @4h30m, #2 @5h')
    assert_equal [[2, '4h30m'], [2, '5h']], log_entries
  end

  def test_parse_message_for_hooks
    parser = RedmineUndevGit::Services::MessageParser.new(nil, %w{fix open})
    hooks  = parser.parse_message_for_hooks('one #1 fix #2,#3 open #4,5')
    assert_equal [[2, 'fix'], [3, 'fix'], [4, 'open']], hooks
  end
end
