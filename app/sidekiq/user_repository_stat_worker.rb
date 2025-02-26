class UserRepositoryStatWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id, github_repository_id = nil)
    user = User.find_by(id: user_id)
    return if user.nil? || user.github_account.nil?

    username = user.github_account.github_username

    LoggerExtension.log(:info, "Starting User Repository Stat calculations.", {
      username: user.github_account.github_username,
      user_id: user_id,
      worker: "UserRepositoryStatWorker"
    })

    if github_repository_id
      find_contributions_for_single_repo(user_id, username, github_repository_id)
    else
      find_contributions_for_multiple_repos(user_id, username)
    end

    LoggerExtension.log(:info, "User Repository Stat calculations completed.", {
      username: user.github_account.github_username,
      user_id: user_id,
      worker: "UserRepositoryStatWorker"
    })
  end

  private

  def find_contributions_for_single_repo(user_id, username, github_repository_id)
    all_prs = PullRequest.where(github_repository_id: github_repository_id, author_username: username)
    all_issues = Issue.where(github_repository_id: github_repository_id, author_username: username)

    process_repository_stats(user_id, github_repository_id, all_prs, all_issues)
  end

  def find_contributions_for_multiple_repos(user_id, username)
    all_prs = PullRequest.where(author_username: username).group_by(&:github_repository_id)
    all_issues = Issue.where(author_username: username).group_by(&:github_repository_id)

    repository_ids = (all_prs.keys + all_issues.keys).uniq

    repository_ids.each do |repo_id|
      repo_prs = all_prs[repo_id] || []
      repo_issues = all_issues[repo_id] || []

      process_repository_stats(user_id, repo_id, repo_prs, repo_issues)
    end
  end

  def process_repository_stats(user_id, repo_id, prs, issues)
    # Find or create stats record
    stats = UserRepositoryStat.find_or_initialize_by(
      user_id: user_id,
      github_repository_id: repo_id
    )

    stats.opened_prs_count = prs.size
    stats.merged_prs_count = prs.count { |pr| pr.merged_at.present? }
    stats.closed_prs_count = prs.count { |pr| pr.closed_at.present? && pr.merged_at.nil? }

    stats.issues_opened_count = issues.size
    stats.issues_closed_count = issues.count { |issue| issue.closed_at.present? }

    contribution_dates = (prs + issues).map { |item| item.github_created_at }
    if contribution_dates.any?
      stats.first_contribution_at = contribution_dates.min
      stats.last_contribution_at = contribution_dates.max
    end

    stats.contribution_streak = calculate_streak(contribution_dates)

    # Save the stats
    stats.save!
  end

  def calculate_streak(dates)
    return 0 if dates.empty?

    dates = dates.map { |date| Date.parse(date.strftime("%Y-%m-%d")) }.uniq
    current_date = Date.today
    streak = 0

    while true
      previous_date = current_date - 1
      if dates.include?(previous_date)
        streak += 1
        current_date = previous_date
      else
        break
      end
    end

    streak
  end
end
