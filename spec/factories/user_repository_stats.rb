FactoryBot.define do
  factory :user_repository_stat do
    user
    github_repository
    opened_prs_count { rand(0..10) }
    merged_prs_count { rand(0..5) }
    issues_opened_count { rand(0..10) }
    issues_closed_count { rand(0..5) }
    issues_with_pr_count { rand(0..3) }
    closed_prs_count { rand(0..3) }
    contribution_streak { rand(0..5) }
    last_contribution_at { 1.day.ago }
    first_contribution_at { 3.months.ago }
  end
end
