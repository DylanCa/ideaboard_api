# app/sidekiq/reference_processor_worker.rb
class ReferenceProcessorWorker
  include BaseWorker

  sidekiq_options queue: :low_priority

  def execute
    # Get unprocessed references (limit to avoid overloading)
    unprocessed_references = PullRequestIssue.unprocessed.limit(500)

    return { processed_count: 0 } if unprocessed_references.empty?

    # Extract unique PR and Issue identifiers
    pr_identifiers = unprocessed_references.pluck(:pr_repository, :pr_number).uniq
    issue_identifiers = unprocessed_references.pluck(:issue_repository, :issue_number).uniq

    # Collect all unique repository names
    pr_repos = pr_identifiers.map(&:first).uniq
    issue_repos = issue_identifiers.map(&:first).uniq
    all_repos = (pr_repos + issue_repos).uniq

    # Find which repositories we already have
    existing_repos = GithubRepository.where(full_name: all_repos).pluck(:id, :full_name).to_h
    existing_repo_names = existing_repos.values

    # Identify repositories we don't have yet
    missing_repos = all_repos - existing_repo_names

    # For repositories we do have, check if we have the PRs and Issues

    # Check PRs - get all PR numbers that we already have for each repository
    existing_prs = PullRequest.joins(:github_repository)
                              .where(github_repositories: { full_name: existing_repo_names })
                              .pluck("github_repositories.full_name", :number)
                              .group_by(&:first)
                              .transform_values { |pairs| pairs.map(&:last) }

    # Check Issues - get all Issue numbers that we already have for each repository
    existing_issues = Issue.joins(:github_repository)
                           .where(github_repositories: { full_name: existing_repo_names })
                           .pluck("github_repositories.full_name", :number)
                           .group_by(&:first)
                           .transform_values { |pairs| pairs.map(&:last) }

    # Enqueue repository fetching for missing repositories
    if missing_repos.any?
      missing_repos.each do |repo_name|
        RepositoryDataFetcherWorker.perform_async(repo_name)
      end
    end

    # For existing repositories, check for specific missing items
    missing_specific_items = []

    # Check for missing PRs
    pr_identifiers.each do |repo, number|
      next if missing_repos.include?(repo) # Skip if repo isn't in our DB yet

      repo_prs = existing_prs[repo] || []
      missing_specific_items << { repo: repo, type: "pr", number: number } unless repo_prs.include?(number)
    end

    # Check for missing Issues
    issue_identifiers.each do |repo, number|
      next if missing_repos.include?(repo) # Skip if repo isn't in our DB yet

      repo_issues = existing_issues[repo] || []
      missing_specific_items << { repo: repo, type: "issue", number: number } unless repo_issues.include?(number)
    end

    # For specific missing items, fetch them directly
    missing_specific_items.each do |item|
      SpecificItemFetcherWorker.perform_async(item[:repo], item[:type], item[:number])
    end

    # Mark as processed any references where we have all data
    fully_processable_references = []

    unprocessed_references.each do |reference|
      pr_repo = reference.pr_repository
      pr_num = reference.pr_number
      issue_repo = reference.issue_repository
      issue_num = reference.issue_number

      # Skip if any repository is missing
      next if missing_repos.include?(pr_repo) || missing_repos.include?(issue_repo)

      # Skip if PR is missing
      pr_exists = (existing_prs[pr_repo] || []).include?(pr_num)
      next unless pr_exists

      # Skip if Issue is missing
      issue_exists = (existing_issues[issue_repo] || []).include?(issue_num)
      next unless issue_exists

      # Both PR and Issue exist, can mark as processed
      fully_processable_references << reference.id
    end

    # Mark references as processed where we have both PR and Issue
    if fully_processable_references.any?
      PullRequestIssue.where(id: fully_processable_references)
                      .update_all(processed_at: Time.current)
    end

    {
      processed_count: fully_processable_references.count,
      repositories_to_fetch: missing_repos.count,
      specific_items_to_fetch: missing_specific_items.count
    }
  end
end
