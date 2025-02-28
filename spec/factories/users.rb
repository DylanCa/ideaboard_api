FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    account_status { :enabled }

    trait :with_github_account do
      after(:create) do |user|
        create(:github_account, user: user)
      end
    end

    trait :with_access_token do
      after(:create) do |user|
        create(:user_token, user: user, access_token: 'test_access_token')
      end
    end
  end
end
