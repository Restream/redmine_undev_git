require File.expand_path('../../test_helper', __FILE__)

class RemoteRepoRevisionTest < ActiveSupport::TestCase

  def test_committer_string
    rev = create(:remote_repo_revision,
      committer_name:  'Some Name',
      committer_email: 'someemail@example.org'
    )
    assert_equal 'Some Name <someemail@example.org>', rev.committer_string
  end

  def test_author_string
    rev = create(:remote_repo_revision,
      author_name:  'Some Name',
      author_email: 'someemail@example.org'
    )
    assert_equal 'Some Name <someemail@example.org>', rev.author_string
  end
end
