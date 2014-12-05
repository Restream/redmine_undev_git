FactoryGirl.define do
  factory :remote_repo_hook do
    issue
    repo
    hook { generate :global_hook }
  end
end
