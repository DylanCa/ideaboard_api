FactoryBot.define do
  factory :pull_request do
    github_repository
    sequence(:github_id) { |n| "pr-#{n}" }
    sequence(:title) { |n| "Pull Request #{n}" }
    sequence(:number) { |n| n }
    url { "https://github.com/owner/repo/pull/#{number}" }
    author_username { "test-author" }
    is_draft { false }
    github_created_at { 1.month.ago }
    github_updated_at { 1.day.ago }
    merged_at { nil }
    closed_at { nil }
    commits { rand(1..10) }
    total_comments_count { rand(0..5) }
  end
end
