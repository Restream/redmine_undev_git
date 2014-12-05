FactoryGirl.define do
  factory :issue do
    subject { generate(:name) }
    association :priority, :factory => :enum_issue_priority
    project
    tracker
    author
    status
  end
end
