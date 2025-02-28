FactoryBot.define do
  factory :github_account do
    user
    github_id { Faker::Number.number(digits: 7) }
    github_username { Faker::Internet.username }
    avatar_url { Faker::Avatar.image }
  end
end
