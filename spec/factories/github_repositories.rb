FactoryBot.define do
  factory :github_repository do
    sequence(:full_name) { |n| "owner/repo-#{n}" }
    sequence(:github_id) { |n| "github-repo-#{n}" }
    stars_count { rand(0..1000) }
    forks_count { rand(0..100) }
    has_contributing { [ true, false ].sample }
    github_created_at { 1.year.ago }
    github_updated_at { 1.day.ago }
    is_fork { false }
    archived { false }
    disabled { false }
    license { "mit" }
    visible { true }
    author_username { "test-author" }
    language { %w[javascript python go php rust java swift kotlin c_sharp].sample }
    update_method { 0 }
    last_polled_at { 2.days.ago }
    app_installed { false }
    webhook_installed { false }
  end
end
