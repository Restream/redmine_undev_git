FactoryGirl.define do
  factory :tracker do
    name
    association :default_status, factory: :issue_status
  end
end
