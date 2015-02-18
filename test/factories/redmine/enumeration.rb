FactoryGirl.define do
  factory :enumeration do
    name

    factory :enum_document_category do
      type 'DocumentCategory'
    end

    factory :enum_issue_priority do
      type 'IssuePriority'
    end

    factory :enum_time_entry_activity do
      type 'TimeEntryActivity'
    end

    factory :enum_enumeration do
      type 'Enumeration'
    end
  end
end
