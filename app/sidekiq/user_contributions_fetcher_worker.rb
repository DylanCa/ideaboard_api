class UserContributionsFetcherWorker
  include BaseWorker

  def execute(user_id)
    user = User.find_by(id: user_id)
    return nil if user.nil? || user.github_account.nil?

    items = { repositories: Set.new, prs: [], issues: [] }

    fetch_newly_created_repos(user)
    fetch_newly_updated_contributions(user, items)

    # Process the new repository contributions before updating other data
    process_new_repository_contributions(user, items)

    user.github_account.update(last_polled_at: Time.current)

    process_github_data(items)
    UserRepositoryStatWorker.perform_async(user.id)

    {
      username: user.github_account.github_username,
      repos_count: items[:repositories].size,
      prs_count: items[:prs].count,
      issues_count: items[:issues].count
    }
  end

  private

  def fetch_newly_created_repos(user)
    repos_result = GithubRepositoryServices::QueryService.fetch_user_repos(
      user.github_account.github_username,
      user.github_account.last_polled_at_date
    )

    if repos_result && repos_result[0]
      Persistence::RepositoryPersistenceService.persist_many(repos_result[0])
    end
  end

  def fetch_newly_updated_contributions(user, items)
    [ :prs, :issues ].each do |contrib_type|
      GithubRepositoryServices::QueryService.fetch_user_contributions(
        user.github_account.github_username,
        items,
        contrib_type,
        user.github_account.last_polled_at_date
      )
    end

    GithubRepositoryServices::ProcessingService.process_contributions(items)
  end

  def process_new_repository_contributions(user, items)
    # 1. Extract all repositories from the items
    all_repo_ids = Set.new

    # Extract repository IDs from PRs
    items[:prs].each do |pr|
      repo = GithubRepository.find_by(github_id: pr.repository.id)
      all_repo_ids.add(repo.id) if repo
    end

    # Extract repository IDs from issues
    items[:issues].each do |issue|
      repo = GithubRepository.find_by(github_id: issue.repository.id)
      all_repo_ids.add(repo.id) if repo
    end

    # 2. Get the list of repositories the user has already contributed to
    existing_repo_ids = UserRepositoryStat.where(user_id: user.id).pluck(:github_repository_id)

    # 3. Find repositories that are new to this user
    new_repo_ids = all_repo_ids.to_a - existing_repo_ids

    # 4. For each new repository, find the earliest contribution
    new_repo_ids.each do |repo_id|
      repository = GithubRepository.find_by(id: repo_id)
      next unless repository

      # Find the earliest contribution date for this repository
      earliest_date = find_earliest_contribution_date(user, items, repository)
      next unless earliest_date

      # Record the new repository contribution
      ReputationService.record_new_repository_contribution(user, repository, earliest_date)

      LoggerExtension.log(:info, "Recorded new repository contribution", {
        user_id: user.id,
        repository_id: repository.id,
        repository_name: repository.full_name,
        contribution_date: earliest_date
      })
    end
  end

  def find_earliest_contribution_date(user, items, repository)
    dates = []

    # Look through PRs
    items[:prs].each do |pr|
      if pr.repository.id == repository.github_id
        # Use PR creation date (not merged date) as the first contribution
        dates << DateTime.parse(pr.created_at)
      end
    end

    # Look through issues
    items[:issues].each do |issue|
      if issue.repository.id == repository.github_id
        dates << DateTime.parse(issue.created_at)
      end
    end

    # Return the earliest date or nil if no dates found
    dates.min
  end

  def process_github_data(items)
    # Extract PR and issue data
    prs = items[:prs] || []
    issues = items[:issues] || []

    # Prepare events collection
    events = []

    # Add PR creation events
    prs.each do |pr|
      # Extract user ID
      user_id = find_user_id_from_username(pr.author&.login)
      next unless user_id

      # Check for merged PR
      if pr.merged_at.present?
        events << {
          type: :pr_merged,
          date: DateTime.parse(pr.merged_at),
          pr_data: pr,
          user_id: user_id
        }
      elsif pr.closed_at.present?
        events << {
          type: :pr_closed,
          date: DateTime.parse(pr.closed_at),
          pr_data: pr,
          user_id: user_id
        }
      end
    end

    # Add issue events
    issues.each do |issue|
      user_id = find_user_id_from_username(issue.author&.login)
      next unless user_id

      # Add issue creation event
      events << {
        type: :issue_opened,
        date: DateTime.parse(issue.created_at),
        issue_data: issue,
        user_id: user_id
      }

      # Add issue closing event if applicable
      if issue.closed_at.present?
        events << {
          type: :issue_closed,
          date: DateTime.parse(issue.closed_at),
          issue_data: issue,
          user_id: user_id
        }
      end
    end

    # Process events by user and date
    process_events_by_date(events)
  end

  def process_events_by_date(events)
    # Group events by user ID
    events_by_user = events.group_by { |e| e[:user_id] }

    results = {}

    # Process each user's events
    events_by_user.each do |user_id, user_events|
      user = User.find_by(id: user_id)
      next unless user

      # Group events by date (ignoring time)
      events_by_date = user_events.group_by { |e| e[:date].to_date }

      # Sort dates in ascending order (oldest first)
      sorted_dates = events_by_date.keys.sort

      # Process each date's events in a transaction
      sorted_dates.each do |date|
        date_events = events_by_date[date]

        # Process events within a transaction to ensure database consistency
        ActiveRecord::Base.transaction do
          date_events.each do |event|
            process_single_event(event, user)
          end
        end

        # Log successful processing
        LoggerExtension.log(:info, "Processed reputation events", {
          user_id: user_id,
          date: date,
          event_count: date_events.count
        })
      end

      # Update user's total reputation
      reputation = ReputationService.update_user_reputation(user)
      results[user_id] = { events_processed: user_events.count, reputation: reputation }
    end

    results
  end

  def process_single_event(event, user)
    case event[:type]
    when :pr_merged
      process_merged_pr(event[:pr_data], user)
    when :pr_closed
      process_closed_pr(event[:pr_data], user)
    when :issue_opened
      process_opened_issue(event[:issue_data], user)
    when :issue_closed
      process_closed_issue(event[:issue_data], user)
    end
  end

  def process_merged_pr(pr_data, user)
    # Check if we already have this PR in our database
    repo = GithubRepository.find_by(github_id: pr_data.repository.id)
    return unless repo

    local_pr = PullRequest.find_by(
      github_repository_id: repo.id,
      number: pr_data.number
    )

    # Ensure we have a PR in our database
    return unless local_pr

    unless ReputationEvent.exists?(
      pull_request_id: local_pr.id,
      event_type: ReputationEvent::TYPES[:pr_merged]
    )
      ReputationService.record_merged_pr(local_pr)
    end
  end

  def process_closed_pr(pr_data, user)
    repo = GithubRepository.find_by(github_id: pr_data.repository.id)
    return unless repo

    local_pr = PullRequest.find_by(
      github_repository_id: repo.id,
      number: pr_data.number
    )

    # Ensure we have a PR in our database
    return unless local_pr

    unless ReputationEvent.exists?(
      pull_request_id: local_pr.id,
      event_type: ReputationEvent::TYPES[:pr_closed]
    )
      ReputationService.record_closed_pr(local_pr)
    end
  end

  def process_opened_issue(issue_data, user)
    repo = GithubRepository.find_by(github_id: issue_data.repository.id)
    return unless repo

    local_issue = Issue.find_by(
      github_repository_id: repo.id,
      number: issue_data.number
    )

    # Ensure we have an issue in our database
    return unless local_issue

    unless ReputationEvent.exists?(
      issue_id: local_issue.id,
      event_type: ReputationEvent::TYPES[:issue_opened]
    )
      ReputationService.record_opened_issue(local_issue)
    end
  end

  def process_closed_issue(issue_data, user)
    repo = GithubRepository.find_by(github_id: issue_data.repository.id)
    return unless repo

    local_issue = Issue.find_by(
      github_repository_id: repo.id,
      number: issue_data.number
    )

    # Ensure we have an issue in our database
    return unless local_issue

    unless ReputationEvent.exists?(
      issue_id: local_issue.id,
      event_type: ReputationEvent::TYPES[:issue_closed]
    )
      ReputationService.record_closed_issue(local_issue)
    end
  end

  def find_user_id_from_username(github_username)
    return nil unless github_username
    account = GithubAccount.find_by(github_username: github_username)
    account&.user_id
  end
end
