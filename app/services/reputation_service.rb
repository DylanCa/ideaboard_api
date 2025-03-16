class ReputationService
  # Define point constants
  BASE_POINTS_MERGED_PR = 100
  ISSUE_CLOSURE_BONUS = 25
  PR_PENALTY = -15
  BASE_POINTS_OPEN_ISSUE = 30
  BASE_POINTS_CLOSE_ISSUE = 20
  PR_CLOSE_BONUS = 15
  NEW_REPO_CONTRIBUTION = 200

  class << self
    # Record reputation for a new repository contribution
    def record_new_repository_contribution(user, repository, occurred_at)
      return unless user.present? && repository.present?

      # Base points for new repository contribution
      base_points = NEW_REPO_CONTRIBUTION

      # Create the reputation event
      ReputationEvent.create!(
        user: user,
        github_repository: repository,
        points_change: base_points,
        event_type: ReputationEvent::TYPES[:new_repository_contribution],
        occurred_at: occurred_at,
        points_breakdown: {
          base_points: base_points,
          reason: "First contribution to #{repository.full_name}"
        }
      )

      # Update the user's total reputation
      update_user_reputation(user)
    end

    # Calculate and record reputation for a merged PR
    def record_merged_pr(pull_request)
      return unless pull_request.merged_at.present?

      user = User.joins(:github_account)
                 .find_by(github_accounts: { github_username: pull_request.author_username })
      return unless user.present?

      repo = pull_request.github_repository

      # 1. Base points for merged PR (increased)
      base_points = BASE_POINTS_MERGED_PR

      # 2. Repository notoriety factor (reduced impact)
      repo_factor = 1 + Math.log10([ repo.stars_count, 1 ].max) / 10.0

      # 3. Issue bonus points for PRs that close issues (increased)
      related_issues = PullRequestIssue.where(
        pr_repository: repo.full_name,
        pr_number: pull_request.number
      ).count

      issue_bonus = related_issues * ISSUE_CLOSURE_BONUS

      # Calculate subtotal before streak bonus
      subtotal = (base_points + issue_bonus) * repo_factor

      # 5. Apply streak bonus
      points_before_streak = subtotal.round
      points_with_streak, streak_percentage = apply_streak_bonus(points_before_streak, user, pull_request.merged_at)

      # Create the reputation event with detailed breakdown
      ReputationEvent.create!(
        user: user,
        github_repository: repo,
        pull_request: pull_request,
        points_change: points_with_streak,
        event_type: ReputationEvent::TYPES[:pr_merged],
        occurred_at: pull_request.merged_at,
        points_breakdown: {
          base_points: base_points,
          repo_factor: repo_factor.round(2),
          issue_bonus: issue_bonus,
          related_issues: related_issues,
          streak_bonus_percentage: streak_percentage,
          streak_bonus_points: points_with_streak - points_before_streak
        }
      )

      # Update the user's total reputation
      update_user_reputation(user)
    end

    # Record reputation for a closed (not merged) PR (increased penalty)
    def record_closed_pr(pull_request)
      return unless pull_request.closed_at.present? && pull_request.merged_at.nil?

      user = User.joins(:github_account)
                 .find_by(github_accounts: { github_username: pull_request.author_username })
      return unless user.present?

      # Penalty for closed PR (no streak bonus for penalties)
      points_change = PR_PENALTY

      ReputationEvent.create!(
        user: user,
        github_repository: pull_request.github_repository,
        pull_request: pull_request,
        points_change: points_change,
        event_type: ReputationEvent::TYPES[:pr_closed],
        occurred_at: pull_request.closed_at,
        points_breakdown: {
          reason: "PR closed without merging",
          base_points: points_change
        }
      )

      # Update the user's total reputation
      update_user_reputation(user)
    end

    # Record reputation for a new issue (increased points)
    def record_opened_issue(issue)
      user = User.joins(:github_account)
                 .find_by(github_accounts: { github_username: issue.author_username })
      return unless user.present?

      repo = issue.github_repository

      # Base points for new issue (increased)
      base_points = BASE_POINTS_OPEN_ISSUE

      # Repository notoriety factor
      repo_factor = 1 + Math.log10([ repo.stars_count, 1 ].max) / 4.0

      # Calculate subtotal before streak bonus
      points_before_streak = (base_points * repo_factor).round

      # Apply streak bonus based on issue creation date
      points_with_streak, streak_percentage = apply_streak_bonus(points_before_streak, user, issue.github_created_at)

      ReputationEvent.create!(
        user: user,
        github_repository: repo,
        issue: issue,
        points_change: points_with_streak,
        event_type: ReputationEvent::TYPES[:issue_opened],
        occurred_at: issue.github_created_at,
        points_breakdown: {
          base_points: base_points,
          repo_factor: repo_factor.round(2),
          streak_bonus_percentage: streak_percentage,
          streak_bonus_points: points_with_streak - points_before_streak
        }
      )

      # Update the user's total reputation
      update_user_reputation(user)
    end

    # Record reputation for closing an issue (increased points)
    def record_closed_issue(issue)
      return unless issue.closed_at.present?

      user = User.joins(:github_account)
                 .find_by(github_accounts: { github_username: issue.author_username })
      return unless user.present?

      repo = issue.github_repository

      # Base points for closing an issue (increased)
      base_points = BASE_POINTS_CLOSE_ISSUE

      # Repository notoriety factor
      repo_factor = 1 + Math.log10([ repo.stars_count, 1 ].max) / 4.0

      # Check if issue was closed by a PR
      closed_by_pr = PullRequestIssue.where(
        issue_repository: repo.full_name,
        issue_number: issue.number
      ).exists?

      # Add bonus if closed by PR (increased)
      pr_bonus = closed_by_pr ? PR_CLOSE_BONUS : 0

      # Calculate subtotal before streak bonus
      points_before_streak = ((base_points + pr_bonus) * repo_factor).round

      # Apply streak bonus based on issue closed date
      points_with_streak, streak_percentage = apply_streak_bonus(points_before_streak, user, issue.closed_at)

      ReputationEvent.create!(
        user: user,
        github_repository: repo,
        issue: issue,
        points_change: points_with_streak,
        event_type: ReputationEvent::TYPES[:issue_closed],
        occurred_at: issue.closed_at,
        points_breakdown: {
          base_points: base_points,
          repo_factor: repo_factor.round(2),
          closed_by_pr: closed_by_pr,
          pr_bonus: pr_bonus,
          streak_bonus_percentage: streak_percentage,
          streak_bonus_points: points_with_streak - points_before_streak
        }
      )

      # Update the user's total reputation
      update_user_reputation(user)
    end

    # Calculate streak bonus percentage based on event date
    def calculate_streak_bonus_percentage(user, current_event_date)
      # Find all previous events for this user
      previous_event = ReputationEvent.where(user: user)
                                      .where("DATE(occurred_at) = ?", current_event_date - 1.day)
                                      .order(occurred_at: :desc)
                                      .limit(1)

      return 0 unless previous_event.present?

      new_percentage = previous_event.first.points_breakdown.symbolize_keys[:streak_bonus_percentage]
      new_percentage = new_percentage.nil? ? 0 : new_percentage + 1
      [ new_percentage, 100 ].min
    end

    # Apply streak bonus to points
    def apply_streak_bonus(base_points, user, event_date)
      bonus_percentage = calculate_streak_bonus_percentage(user, event_date)

      # Calculate bonus points (percentage of base points)
      bonus_points = (base_points * (bonus_percentage / 100.0)).round

      # Return both total points and bonus info
      [ base_points + bonus_points, bonus_percentage ]
    end

    # Update the user's total reputation score
    def update_user_reputation(user)
      total_points = ReputationEvent.where(user: user).sum(:points_change)

      # Update the user_stat reputation points
      user_stat = user.user_stat || user.create_user_stat
      user_stat.update!(reputation_points: total_points)

      # Return the updated total
      total_points
    end

    # Calculate and record reputation for all users (useful for initialization)
    def recalculate_all_reputation
      # Clear existing events to avoid duplicates
      ReputationEvent.delete_all

      # Process all merged PRs
      PullRequest.where.not(merged_at: nil).find_each do |pr|
        record_merged_pr(pr)
      end

      # Process all closed but not merged PRs
      PullRequest.where.not(closed_at: nil).where(merged_at: nil).find_each do |pr|
        record_closed_pr(pr)
      end

      # Process all opened issues
      Issue.find_each do |issue|
        record_opened_issue(issue)
      end

      # Process all closed issues
      Issue.where.not(closed_at: nil).find_each do |issue|
        record_closed_issue(issue)
      end

      # Update all user reputation scores
      User.find_each do |user|
        update_user_reputation(user)
      end
    end

    # Calculate a user's reputation for a specific date range
    def calculate_reputation_for_period(user, start_date, end_date)
      ReputationEvent.where(
        user: user,
        occurred_at: start_date.beginning_of_day..end_date.end_of_day
      ).sum(:points_change)
    end

    # Get highest earners for a specific period
    def top_earners(limit = 10, start_date = nil, end_date = nil)
      query = User.joins(:reputation_events)

      if start_date && end_date
        query = query.where(
          reputation_events: {
            occurred_at: start_date.beginning_of_day..end_date.end_of_day
          }
        )
      end

      query.group("users.id")
           .select("users.*, SUM(reputation_events.points_change) as period_points")
           .order("period_points DESC")
           .limit(limit)
    end

    # Get a detailed breakdown of a user's reputation sources
    def reputation_breakdown(user)
      {
        total: ReputationEvent.where(user: user).sum(:points_change),
        by_type: {
          pr_merged: ReputationEvent.where(user: user, event_type: ReputationEvent::TYPES[:pr_merged]).sum(:points_change),
          pr_closed: ReputationEvent.where(user: user, event_type: ReputationEvent::TYPES[:pr_closed]).sum(:points_change),
          issue_opened: ReputationEvent.where(user: user, event_type: ReputationEvent::TYPES[:issue_opened]).sum(:points_change),
          issue_closed: ReputationEvent.where(user: user, event_type: ReputationEvent::TYPES[:issue_closed]).sum(:points_change)
        },
        by_repository: ReputationEvent.where(user: user)
                                      .joins(:github_repository)
                                      .group("github_repositories.full_name")
                                      .sum(:points_change),
        current_streak_percentage: ReputationEvent.where(user: user)
                                                  .where("occurred_at > ?", 1.day.ago)
                                                  .order(occurred_at: :desc)
                                                  .first&.points_breakdown&.symbolize_keys&.dig(:streak_bonus_percentage) || 0
      }
    end
  end
end
