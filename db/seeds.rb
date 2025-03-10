# This file contains seed data for the IdeaBoard API application
# It creates realistic GitHub-like data for testing and development purposes

# Reset the database counters
ActiveRecord::Base.connection.tables.each do |table|
  ActiveRecord::Base.connection.reset_pk_sequence!(table) unless table == 'schema_migrations'
end

puts "🌱 Seeding database..."

# Error tracking
errors = []

# Helper method to track errors
def safe_create(entity_name)
  begin
    result = yield
    print "."  # Just print a dot for success
    result
  rescue StandardError => e
    print "x"  # Print x for error
    # Only print the error in a new line if it's really an error
    puts "\nERROR creating #{entity_name}: #{e.message}"
    puts e.backtrace[0..2]
    nil
  end
end

# Create Users
print "Creating users "
users = []
25.times do |i|
  user = safe_create("user") do
    user = User.create!(
      email: "user#{i+1}@example.com",
      account_status: User.account_statuses.keys.sample,
      token_usage_level: User.token_usage_levels.keys.sample
    )
    users << user
    user
  end
end
puts " ✅"

# Create GitHub Accounts
print "Creating GitHub accounts "
github_accounts = []
users.compact.each_with_index do |user, i|
  account = safe_create("GitHub account") do
    account = GithubAccount.create!(
      user: user,
      github_id: 1000000 + i,
      github_username: "github-user-#{i+1}",
      avatar_url: "https://avatars.githubusercontent.com/u/#{1000000 + i}",
      last_polled_at: rand(10).days.ago
    )
    github_accounts << account
    account
  end
end
puts " ✅"

# Create User Tokens
print "Creating user tokens "
user_tokens = []
users.compact.each_with_index do |user, i|
  token = safe_create("user token") do
    token = UserToken.create!(
      user: user,
      access_token: "gho_#{SecureRandom.hex(20)}"
    )
    user_tokens << token
    token
  end
end
puts " ✅"

# Create User Stats
print "Creating user stats "
user_stats = []
users.compact.each_with_index do |user, i|
  stat = safe_create("user stat") do
    stat = UserStat.create!(
      user: user,
      reputation_points: rand(0..2000)
    )
    user_stats << stat
    stat
  end
end
puts " ✅"

# Create Topics (formerly Tags)
print "Creating topics "
topics = []
topic_names = [
  "ruby", "rails", "javascript", "react", "typescript", "python", "django", "flask",
  "java", "spring", "golang", "rust", "elixir", "phoenix", "docker", "kubernetes",
  "devops", "aws", "azure", "gcp", "serverless", "machine-learning", "data-science",
  "blockchain", "crypto", "web3", "frontend", "backend", "fullstack", "mobile",
  "ios", "android", "flutter", "react-native", "graphql", "rest", "microservices"
]

topic_names.each do |name|
  topic = safe_create("topic") do
    topic = Topic.create!(
      name: name
    )
    topics << topic
    topic
  end
end
puts " ✅"

# Create GitHub Repositories
print "Creating GitHub repositories "
repositories = []
50.times do |i|
  # Determine owner - either one of our users or an external user
  owner = rand < 0.7 ? github_accounts.sample&.github_username || "default-owner-#{i}" : "external-owner-#{rand(1..20)}"

  safe_create("repository") do
    repo = GithubRepository.create!(
      full_name: "#{owner}/repo-#{i+1}",
      stars_count: rand(0..10000),
      forks_count: rand(0..500),
      has_contributing: [ true, false ].sample,
      github_created_at: rand(1..730).days.ago,
      description: "This is a sample repository #{i+1} with #{[ 'Ruby', 'JavaScript', 'Python', 'Go', 'Java', 'C#', 'PHP' ].sample} code.",
      is_fork: [ true, false ].sample,
      archived: rand < 0.1, # 10% chance of being archived
      disabled: rand < 0.05, # 5% chance of being disabled
      license: [ "mit", "apache-2.0", "gpl-3.0", "bsd-3-clause", "mpl-2.0", nil ].sample,
      visible: rand < 0.9, # 90% chance of being visible
      github_updated_at: rand(1..60).days.ago,
      github_id: "R_kgDOG#{SecureRandom.hex(4)}",
      author_username: owner,
      language: [ "ruby", "javascript", "python", "go", "java", "csharp", "php", "typescript" ].sample,
      update_method: GithubRepository.update_methods.keys.sample,
      last_polled_at: rand < 0.8 ? rand(1..14).days.ago : nil,
      webhook_secret: rand < 0.3 ? SecureRandom.hex(20) : nil,
      app_installed: rand < 0.4,
      webhook_installed: rand < 0.3
    )
    repositories << repo
    repo
  end
end
puts " ✅"

# Associate Topics with Repositories
print "Associating topics with repositories "
repositories.compact.each do |repo|
  # Select 0-5 random topics (without duplicates)
  selected_topics = topics.compact.sample(rand(0..5))

  selected_topics.each do |topic|
    safe_create("repository-topic association") do
      GithubRepositoryTopic.create!(
        github_repository: repo,
        topic: topic
      )
    end
  end
end
puts " ✅"

# Create Labels
print "Creating labels "
labels = []
label_data = [
  { name: "bug", color: "d73a4a", is_bug: true, description: "Something isn't working" },
  { name: "documentation", color: "0075ca", is_bug: false, description: "Improvements or additions to documentation" },
  { name: "duplicate", color: "cfd3d7", is_bug: false, description: "This issue or pull request already exists" },
  { name: "enhancement", color: "a2eeef", is_bug: false, description: "New feature or request" },
  { name: "good first issue", color: "7057ff", is_bug: false, description: "Good for newcomers" },
  { name: "help wanted", color: "008672", is_bug: false, description: "Extra attention is needed" },
  { name: "invalid", color: "e4e669", is_bug: false, description: "This doesn't seem right" },
  { name: "question", color: "d876e3", is_bug: false, description: "Further information is requested" },
  { name: "wontfix", color: "ffffff", is_bug: false, description: "This will not be worked on" },
  { name: "dependencies", color: "0366d6", is_bug: false, description: "Pull requests that update a dependency file" },
  { name: "security", color: "ee0701", is_bug: true, description: "Security vulnerability or concern" },
  { name: "performance", color: "16c60c", is_bug: false, description: "Performance improvement" },
  { name: "refactor", color: "fbca04", is_bug: false, description: "Code refactoring" },
  { name: "ui", color: "fef2c0", is_bug: false, description: "UI/UX improvements" },
  { name: "feature", color: "0e8a16", is_bug: false, description: "New feature implementation" },
  { name: "test", color: "c5def5", is_bug: false, description: "Test improvements" },
  { name: "high-priority", color: "b60205", is_bug: false, description: "High priority issue" },
  { name: "blocked", color: "b60205", is_bug: false, description: "Work blocked by other tasks" },
  { name: "needs-review", color: "5319e7", is_bug: false, description: "Needs review from maintainers" },
  { name: "ready-to-merge", color: "0e8a16", is_bug: false, description: "Ready to be merged" }
]

repositories.compact.each do |repo|
  # Each repository gets a random selection of 5-15 labels
  selected_labels = label_data.sample(rand(5..15))

  selected_labels.each do |label_attrs|
    label = safe_create("label") do
      label = Label.create!(
        name: label_attrs[:name],
        color: label_attrs[:color],
        description: label_attrs[:description],
        is_bug: label_attrs[:is_bug],
        github_repository: repo
      )
      labels << label
      label
    end
  end
end
puts " ✅"

# Step 1: Create Pull Requests
print "Creating pull requests "
pull_requests = []
repositories.compact.each do |repo|
  # Create between 5-30 PRs per repository
  rand(5..30).times do |i|
    # Determine author - either one of our users or an external user
    author = rand < 0.6 ? github_accounts.sample&.github_username || "default-author-#{i}" : "external-contributor-#{rand(1..50)}"

    # Create a PR in different states
    is_merged = rand < 0.4 # 40% chance of being merged
    is_closed_not_merged = !is_merged && rand < 0.3 # 30% chance of being closed without merging
    is_draft = !is_merged && !is_closed_not_merged && rand < 0.2 # 20% chance of being a draft PR if open

    merged_at = is_merged ? rand(1..30).days.ago : nil
    closed_at = (is_merged || is_closed_not_merged) ? (merged_at || rand(1..30).days.ago) : nil

    created_at = rand(60..365).days.ago
    updated_at = [ created_at + rand(1..30).days, Time.current ].min

    pr = safe_create("pull request") do
      PullRequest.create!(
        github_repository: repo,
        github_id: "PR_kwDOG#{SecureRandom.hex(6)}",
        title: "#{[ 'Fix', 'Update', 'Add', 'Remove', 'Refactor', 'Implement', 'Optimize' ].sample} #{[ 'bug in', 'feature for', 'documentation of', 'tests for', 'performance of', 'UI of', 'API for' ].sample} #{Faker::Hacker.noun}",
        merged_at: merged_at,
        github_created_at: created_at,
        github_updated_at: updated_at,
        url: "https://github.com/#{repo.full_name}/pull/#{i+1}",
        number: i+1,
        author_username: author,
        is_draft: is_draft,
        commits: rand(1..20),
        total_comments_count: rand(0..15),
        closed_at: closed_at
      )
    end

    pull_requests << pr if pr
  end
end
puts " ✅"

# Step 2: Create Labels for Pull Requests
print "Creating pull request labels "
pull_requests.compact.each do |pr|
  repo = pr.github_repository
  repo_labels = Label.where(github_repository: repo)

  # Skip if no labels exist for this repo
  unless repo_labels.empty?
    # Select distinct random labels to avoid duplicates
    selected_labels = repo_labels.to_a.sample(rand(0..4))

    selected_labels.each do |label|
      safe_create("pull request label") do
        PullRequestLabel.create!(
          pull_request: pr,
          label: label
        )
      end
    end
  end
end
puts " ✅"

# Create Issues
print "Creating issues "
issues = []
repositories.compact.each do |repo|
  # Create between 10-50 issues per repository
  rand(10..50).times do |i|
    # Determine author - either one of our users or an external user
    author = rand < 0.6 ? github_accounts.sample&.github_username || "default-author-#{i}" : "external-contributor-#{rand(1..50)}"

    # Determine if issue is closed
    is_closed = rand < 0.4 # 40% chance of being closed

    created_at = rand(60..365).days.ago
    updated_at = [ created_at + rand(1..30).days, Time.current ].min
    closed_at = is_closed ? [ updated_at - rand(1..5).days, Time.current ].min : nil

    issue = safe_create("issue") do
      Issue.create!(
        github_repository: repo,
        github_id: "I_kwDOG#{SecureRandom.hex(6)}",
        title: "#{[ 'Bug', 'Feature request', 'Documentation', 'Question about', 'Problem with', 'How to use', 'Error in' ].sample}: #{Faker::Hacker.say_something_smart}",
        github_created_at: created_at,
        github_updated_at: updated_at,
        url: "https://github.com/#{repo.full_name}/issues/#{i+100}", # Start issue numbering at 100 to distinguish from PRs
        number: i+100,
        author_username: author,
        comments_count: rand(0..20),
        closed_at: closed_at
      )
    end

    issues << issue if issue
  end
end
puts " ✅"

# Create Labels for Issues
print "Creating issue labels "
issues.compact.each do |issue|
  repo = issue.github_repository
  repo_labels = Label.where(github_repository: repo)

  # Skip if no labels exist for this repo
  unless repo_labels.empty?
    # Select distinct random labels to avoid duplicates
    selected_labels = repo_labels.to_a.sample(rand(0..5))

    selected_labels.each do |label|
      safe_create("issue label") do
        IssueLabel.create!(
          issue: issue,
          label: label
        )
      end
    end
  end
end
puts " ✅"

# Create User Repository Stats
print "Creating user repository stats..."
users.each do |user|
  # Each user contributes to 1-10 repositories
  user_repos = repositories.sample(rand(1..10))

  user_repos.each do |repo|
    # Check if stats already exist for this user-repo combination
    next if UserRepositoryStat.exists?(user_id: user.id, github_repository_id: repo.id)

    # Get actual PR counts for this user in this repo
    user_prs = PullRequest.where(github_repository: repo, author_username: user.github_account.github_username)
    user_issues = Issue.where(github_repository: repo, author_username: user.github_account.github_username)

    opened_prs_count = user_prs.count
    merged_prs_count = user_prs.where.not(merged_at: nil).count
    closed_prs_count = user_prs.where(merged_at: nil).where.not(closed_at: nil).count

    issues_opened_count = user_issues.count
    issues_closed_count = user_issues.where.not(closed_at: nil).count

    # Calculate contribution dates
    all_contributions = user_prs.map(&:github_created_at) + user_issues.map(&:github_created_at)

    # Only create stats if user has actual contributions
    if opened_prs_count > 0 || issues_opened_count > 0
      first_contribution_at = all_contributions.min
      last_contribution_at = all_contributions.max

      # Random streak between 0 and 5
      contribution_streak = rand(0..5)

        safe_create("user repository stat") do
          UserRepositoryStat.create!(
            user: user,
            github_repository: repo,
            opened_prs_count: opened_prs_count,
            merged_prs_count: merged_prs_count,
            closed_prs_count: closed_prs_count,
            issues_opened_count: issues_opened_count,
            issues_closed_count: issues_closed_count,
            issues_with_pr_count: rand(0..issues_closed_count), # Random subset of closed issues have PRs
            first_contribution_at: first_contribution_at,
            last_contribution_at: last_contribution_at,
            contribution_streak: contribution_streak
          )
        end
    end
  end
end
puts " ✅"


# Create Token Usage Logs
print "Creating token usage logs "
50.times do
  # Select random user and repo
  user = users.compact.sample
  repo = repositories.compact.sample

  # Skip if either user or repo is nil
  next if user.nil? || repo.nil?

  # Query types
  query_types = [
    "UserData",
    "UserRepositories",
    "RepositoryData",
    "RepositoryPrs",
    "RepositoryIssues",
    "SearchQuery"
  ]

  query = query_types.sample

  # Create variables based on query type
  variables = case query
  when "RepositoryData", "RepositoryPrs", "RepositoryIssues"
                "{ \"owner\": \"#{repo.full_name.split('/')[0]}\", \"name\": \"#{repo.full_name.split('/')[1]}\" }"
  when "SearchQuery"
                "{ \"query\": \"repo:#{repo.full_name}\", \"type\": \"ISSUE\" }"
  else
                nil
  end

  # Random points used and remaining
  points_used = rand(1..10)
  points_remaining = rand(1000..5000)

  # Create the log
  safe_create("token usage log") do
    TokenUsageLog.create!(
      user: user,
      github_repository: repo,
      query: query,
      variables: variables,
      usage_type: user.token_usage_level,
      points_used: points_used,
      points_remaining: points_remaining,
      created_at: rand(1..30).days.ago
    )
  end
end
puts " ✅"

puts "\n✅ Seed data creation complete!"
puts "\nSummary:"
puts "  #{User.count} users"
puts "  #{GithubAccount.count} GitHub accounts"
puts "  #{UserToken.count} user tokens"
puts "  #{UserStat.count} user stats"
puts "  #{Topic.count} topics"
puts "  #{GithubRepository.count} repositories"
puts "  #{GithubRepositoryTopic.count} repository-topic associations"
puts "  #{Label.count} labels"
puts "  #{PullRequest.count} pull requests"
puts "  #{PullRequestLabel.count} pull request labels"
puts "  #{Issue.count} issues"
puts "  #{IssueLabel.count} issue labels"
puts "  #{UserRepositoryStat.count} user repository stats"
puts "  #{TokenUsageLog.count} token usage logs"
