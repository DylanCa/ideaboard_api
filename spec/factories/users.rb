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

    trait :with_user_stat do
      after(:create) do |user|
        create(:user_stat, user: user)
      end
    end
  end
end
