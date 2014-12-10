FactoryGirl.define do
  factory :remote_repo, aliases: [:repo] do
    site
    sequence(:path_to_repo) { |n| "user#{n}/name#{n}" }
  end
end
