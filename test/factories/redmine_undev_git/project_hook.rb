FactoryGirl.define do
  factory :project_hook do
    project
    branches '*'
    keywords 'fix, fixes, close, closes'
    assignee_type GlobalHook::NOBODY
  end
end
