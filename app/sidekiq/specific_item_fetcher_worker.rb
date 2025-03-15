# app/sidekiq/specific_item_fetcher_worker.rb
class SpecificItemFetcherWorker
  include BaseWorker

  sidekiq_options queue: :low_priority, retry: 3

  def execute(repo_name, item_type, item_number)
    # Ensure repository exists
    repo = GithubRepository.find_by(full_name: repo_name)

    unless repo
      repo_id = RepositoryFetcherWorker.new.perform(repo_name)&.dig("id")
      return nil unless repo_id
      repo = GithubRepository.find(repo_id)
    end

    # Fetch specific item
    if item_type == "pr"
      items = GithubRepositoryServices::SpecificItemFetcherService.fetch_pull_request(repo_name, item_number)
      return nil unless items

      GithubRepositoryServices::PersistenceService.update_repository_items(repo, items, [])
    elsif item_type == "issue"
      items = GithubRepositoryServices::SpecificItemFetcherService.fetch_issue(repo_name, item_number)
      return nil unless items

      GithubRepositoryServices::PersistenceService.update_repository_items(repo, [], items)
    end

    # Mark references as processed where this item was missing
    if item_type == "pr"
      PullRequestIssue.where(pr_repository: repo_name, pr_number: item_number, processed_at: nil)
                      .update_all(processed_at: Time.current)
    else
      PullRequestIssue.where(issue_repository: repo_name, issue_number: item_number, processed_at: nil)
                      .update_all(processed_at: Time.current)
    end

    {
      repository: repo_name,
      type: item_type,
      number: item_number,
      fetched: true
    }
  end
end
