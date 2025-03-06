FactoryBot.define do
  factory :rate_limit_log do
    association :token_owner, factory: :user
    token_owner_type { "User" }
    query_name { "UserData" }
    cost { rand(1..10) }
    remaining_points { rand(3000..5000) }
    reset_at { 1.hour.from_now }
    executed_at { Time.current }
  end
end
