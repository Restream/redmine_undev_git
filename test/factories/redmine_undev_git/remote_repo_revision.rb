FactoryGirl.define do
  factory :remote_repo_revision do
    repo
    sequence(:sha) { |n| Digest::SHA1.hexdigest "sha#{n}" }

    trait :author_info do
      author
      author_string { "#{author.name} <#{author.mail}>" }
      author_date { generate :time_seq }
    end

    trait :committer_info do
      committer
      committer_string { "#{committer.name} <#{committer.mail}>" }
      committer_date { generate :time_seq }
    end

    factory :full_repo_revision, traits: [:author_info, :committer_info] do
      message
    end
  end
end
