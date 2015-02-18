FactoryGirl.define do
  factory :remote_repo_revision do
    repo
    sequence(:sha) { |n| Digest::SHA1.hexdigest "sha#{n}" }

    trait :author_info do
      author
      author_name  { author.name }
      author_email { author.mail }
      author_date  { generate :time_seq }
    end

    trait :committer_info do
      committer
      committer_name  { committer.name }
      committer_email { committer.mail }
      committer_date  { generate :time_seq }
    end

    factory :remote_repo_revision_full, traits: [:author_info, :committer_info] do
      message
    end
  end
end
