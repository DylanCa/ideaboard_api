# app/sidekiq/webhook_event_processor_worker.rb
class WebhookEventProcessorWorker
  include BaseWorker

  def execute(github_event, payload, repository_id)
    repository = GithubRepository.find_by(id: repository_id)
    return nil if repository.nil?

    # Process based on event type
    case github_event
    when "pull_request"
      process_pull_request_event(repository, payload)
    when "issues"
      process_issue_event(repository, payload)
    when "issue_comment"
      process_issue_comment_event(repository, payload)
    when "repository"
      process_repository_event(repository, payload)
    else
      LoggerExtension.log(:error, "Unhandled webhook event type", {
        repository: repository.full_name,
        event: github_event
      })
    end

    {
      repository_id: repository_id,
      repository: repository.full_name,
      event: github_event,
      action: payload["action"],
      processed: true
    }
  end

  private

  def process_pull_request_event(repository, payload)
    pr_action = payload["action"]
    pr_number = payload.dig("pull_request", "number")

    LoggerExtension.log(:info, "Pull request event", {
      repository: repository.full_name,
      action: pr_action,
      pr_number: pr_number
    })

    # For PR creation, update, or merging, fetch the PR data
    if [ "opened", "closed", "edited", "reopened", "synchronize" ].include?(pr_action)
      pull_request = payload["pull_request"]

      # Map the PR data from the webhook to our model
      pr_data = {
        github_id: pull_request["node_id"],
        number: pull_request["number"],
        title: pull_request["title"],
        url: pull_request["html_url"],
        author_username: pull_request.dig("user", "login"),
        is_draft: pull_request["draft"] || false,
        merged_at: pull_request["merged_at"],
        closed_at: pull_request["closed_at"],
        github_created_at: pull_request["created_at"],
        github_updated_at: pull_request["updated_at"],
        github_repository_id: repository.id
      }

      # Update or create the PR in our database
      existing_pr = PullRequest.find_by(github_id: pr_data[:github_id]) ||
        PullRequest.find_by(github_repository_id: repository.id, number: pr_data[:number])

      if existing_pr
        existing_pr.update(pr_data)
      else
        PullRequest.create!(pr_data)
      end

      # Process labels if they're in the payload
      if pull_request["labels"].present?
        labels = pull_request["labels"].map do |label|
          {
            name: label["name"],
            color: label["color"],
            github_repository_id: repository.id
          }
        end

        # Use our label persistence helper
        if existing_pr
          Persistence::Helper.preload_labels(
            labels.map { |l| l[:name] },
            repository.id
          )

          labels.each do |label_data|
            label = Persistence::Helper.get_label_by_name(label_data[:name], repository.id)

            if label
              PullRequestLabel.find_or_create_by(
                pull_request_id: existing_pr.id,
                label_id: label.id
              )
            end
          end
        end
      end

      # Update user stats if PR is merged
      if pr_action == "closed" || pull_request["merged_at"].present?
        author_username = pull_request.dig("user", "login")

        user = User.joins(:github_account)
                   .where(github_accounts: { github_username: author_username })
                   .first

        if user
          UserRepositoryStatWorker.perform_async(user.id, repository.id)
        end
      end
    end
  end

  def process_issue_event(repository, payload)
    issue_action = payload["action"]
    issue_number = payload.dig("issue", "number")

    LoggerExtension.log(:info, "Issue event", {
      repository: repository.full_name,
      action: issue_action,
      issue_number: issue_number
    })

    # For issue creation, update, or closing, fetch the issue data
    if [ "opened", "closed", "edited", "reopened" ].include?(issue_action)
      issue = payload["issue"]

      # Skip if it's actually a pull request
      return if issue["pull_request"].present?

      # Map the issue data from the webhook to our model
      issue_data = {
        github_id: issue["node_id"],
        number: issue["number"],
        title: issue["title"],
        url: issue["html_url"],
        author_username: issue.dig("user", "login"),
        closed_at: issue["closed_at"],
        github_created_at: issue["created_at"],
        github_updated_at: issue["updated_at"],
        comments_count: issue["comments"],
        github_repository_id: repository.id
      }

      # Update or create the issue in our database
      existing_issue = Issue.find_by(github_id: issue_data[:github_id]) ||
        Issue.find_by(github_repository_id: repository.id, number: issue_data[:number])

      if existing_issue
        existing_issue.update(issue_data)
      else
        Issue.create!(issue_data)
      end

      # Process labels if they're in the payload
      if issue["labels"].present?
        labels = issue["labels"].map do |label|
          {
            name: label["name"],
            color: label["color"],
            github_repository_id: repository.id
          }
        end

        # Use our label persistence helper
        if existing_issue
          Persistence::Helper.preload_labels(
            labels.map { |l| l[:name] },
            repository.id
          )

          labels.each do |label_data|
            label = Persistence::Helper.get_label_by_name(label_data[:name], repository.id)

            if label
              IssueLabel.find_or_create_by(
                issue_id: existing_issue.id,
                label_id: label.id
              )
            end
          end
        end
      end

      # Update user stats if issue is closed
      if issue_action == "closed"
        author_username = issue.dig("user", "login")

        user = User.joins(:github_account)
                   .where(github_accounts: { github_username: author_username })
                   .first

        if user
          UserRepositoryStatWorker.perform_async(user.id, repository.id)
        end
      end
    end
  end

  # TODO: Integrate this logic ?
  def process_issue_comment_event(repository, payload)
    # Just log comment events for now, but could update comment count
    comment_action = payload["action"]
    issue_number = payload.dig("issue", "number")

    LoggerExtension.log(:info, "Issue comment event", {
      repository: repository.full_name,
      action: comment_action,
      issue_number: issue_number
    })
  end

  def process_repository_event(repository, payload)
    # Handle repository updates
    repo_action = payload["action"]

    LoggerExtension.log(:info, "Repository event", {
      repository: repository.full_name,
      action: repo_action
    })

    # Update repository information
    RepositoryFetcherWorker.perform_async(repository.full_name)
  end
end
