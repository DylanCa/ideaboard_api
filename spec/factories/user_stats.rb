FactoryBot.define do
  factory :user_stat do
    user
    reputation_points { rand(0..1000) }
  end
end
