FactoryGirl.define do
  factory :project do
    name
    identifier

    factory :project_with_tracker do
      transient do
        tracker { create :tracker }
      end

      after(:create) do |project, evaluator|
        project.trackers << evaluator.tracker unless project.trackers.include? evaluator.tracker
      end
    end
  end
end
