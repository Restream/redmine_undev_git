FactoryGirl.define do
  factory :global_hook do
    branches '*'
    keywords 'fix, fixes, close, closes'
    assignee_type GlobalHook::NOBODY
  end
end
