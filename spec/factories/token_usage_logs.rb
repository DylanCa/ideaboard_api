FactoryBot.define do
  factory :token_usage_log do
    user
    github_repository
    query { "UserData" }
    variables { nil }
    usage_type { rand(0..2) }
    points_used { rand(1..10) }
    points_remaining { rand(3000..5000) }
  end
end
