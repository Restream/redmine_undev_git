FactoryGirl.define do
  factory :issue do
    subject { generate(:name) }
    priority
    tracker
    project { create(:project_with_tracker, tracker: tracker) }
    author
    status
  end
end
