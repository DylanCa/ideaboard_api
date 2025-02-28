class RepositoryDataFetcherWorker
  include BaseWorker

  def execute(repo_full_name)
    repo_id = RepositoryFetcherWorker.new.perform(repo_full_name)&.dig("id")
    return unless repo_id

    ItemsFetcherWorker.perform_async(repo_id, "prs")
    ItemsFetcherWorker.perform_async(repo_id, "issues")

    { repository: repo_full_name, fetched: true }
  end
end
