FactoryBot.define do
  factory :label do
    sequence(:name) { |n| "label-#{n}" }
    color { "ff0000" }
    description { "Test label" }
    is_bug { false }
    github_repository
  end
end
