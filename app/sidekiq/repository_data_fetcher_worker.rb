class RepositoryDataFetcherWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(repo_full_name)
    repo_id = RepositoryFetcherWorker.new.perform(repo_full_name)["id"]

    ItemsFetcherWorker.perform_async(repo_id, "prs")
    ItemsFetcherWorker.perform_async(repo_id, "issues")
  end
end
