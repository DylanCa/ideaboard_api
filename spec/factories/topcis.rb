FactoryBot.define do
  factory :topic do
    sequence(:name) { |n| "topic-#{n}" }
  end
end
