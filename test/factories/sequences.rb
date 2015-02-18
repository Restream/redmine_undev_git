FactoryGirl.define do
  sequence :name do |n|
    "name_#{n}"
  end

  sequence :email do |n|
    "somebody#{n}@example.org"
  end

  sequence :identifier do |n|
    "identifier_#{n}"
  end

  sequence :message do |n|
    "this text ##{n} is a bit longer than a simple name"
  end

  sequence :time_seq do |n|
    Time.now - 1.month + n.minutes
  end
end
