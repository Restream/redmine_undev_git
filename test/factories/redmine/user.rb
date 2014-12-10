FactoryGirl.define do
  factory :user, :aliases => [:author, :committer], :class => User do
    login     { generate :name }
    firstname { generate :name }
    lastname  { generate :name }
    mail      { generate :email }
    status    1 # Older version of redmine does not have Principal::STATUS_ACTIVE constant
  end

end
