class RepositoryUpdateWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(repo_id)
    repo = GithubRepository.find_by(id: repo_id)
    return if repo.nil?

    RepositoryFetcherWorker.new.perform(repo.full_name)
    GithubRepositoryServices::QueryService.fetch_updates(repo.full_name, repo.last_polled_at_date)
    repo.update(last_polled_at: Time.current)
  end
end
