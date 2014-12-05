FactoryGirl.define do
  factory :user, :aliases => [:author, :committer], :class => User do
    name

    factory :active_user do
      status Principal::STATUS_ACTIVE
    end
  end

end
