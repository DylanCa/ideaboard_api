FactoryBot.define do
  factory :user_token do
    user
    access_token { Faker::Crypto.sha256 }
  end
end
