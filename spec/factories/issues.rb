FactoryBot.define do
  factory :issue do
    github_repository
    sequence(:github_id) { |n| "issue-#{n}" }
    sequence(:title) { |n| "Issue #{n}" }
    sequence(:number) { |n| n }
    url { "https://github.com/owner/repo/issues/#{number}" }
    author_username { "test-author" }
    github_created_at { 1.month.ago }
    github_updated_at { 1.day.ago }
    closed_at { nil }
    comments_count { rand(0..5) }
  end
end
