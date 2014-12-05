FactoryGirl.define do
  factory :remote_repo_site, :aliases => [:site] do
    sequence(:server_name) { |n| "server#{n}.com" }

    factory :remote_repo_site_with_repos do
      transient do
        repos_count 1
      end

      after(:create) do |site, evaluator|
        create_list(:remote_repo_site, evaluator.repos_count, site: site)
      end
    end
  end
end
