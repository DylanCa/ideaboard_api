require_relative "../../models/github/repository"

module Persistence
  class RepositoryPersistenceService
    extend T::Sig

    def self.persist_many(repositories)
      validate_bulk_input!(repositories)

      repos = []
      raw_topics = {}

      repositories.each do |repo|
        topics = repo.repository_topics.nodes.map { |t| Github::Topic.from_github(t).stringify_keys }
        raw_topics[repo.id] = topics
        repos << Github::Repository.from_github(repo).stringify_keys
      end

      inserted_repos = GithubRepository.upsert_all(
        repos,
        unique_by: :github_id,
        returning: %w[id github_id]
      )

      Helper.insert_items_labels_if_any(raw_topics, inserted_repos, :repositories)

      inserted_repos
    end

    private

    sig { params(repositories: T::Array[Github::Repository]).void }
    def self.validate_bulk_input!(repositories)
      raise ArgumentError, "Repositories cannot be nil" if repositories.nil?
    end
  end
end
