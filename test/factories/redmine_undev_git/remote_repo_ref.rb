FactoryGirl.define do
  factory :remote_repo_ref do
    repo
    sequence(:branch) { |n| "branch#{n}" }
  end
end
