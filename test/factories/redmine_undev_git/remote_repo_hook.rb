FactoryGirl.define do
  factory :remote_repo_hook do
    issue
    revision { create :remote_repo_revision }
    hook     { create :global_hook }
  end
end
