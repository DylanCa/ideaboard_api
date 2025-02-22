class RepositoryDataFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(repo_id)
    repo = GithubRepository.find_by(id: repo_id)
    return if repo.nil?

    # Step 1: Update repository metadata
    RepositoryFetcherWorker.perform_async(repo.full_name)

    # Step 2: Schedule items fetching with a delay to avoid rate limiting
    ItemsFetcherWorker.perform_async(repo.id, "prs")
    ItemsFetcherWorker.perform_async(repo.id, "issues")
  end
end
