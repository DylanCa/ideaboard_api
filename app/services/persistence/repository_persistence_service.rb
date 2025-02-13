require_relative "../../models/github/repository"

module Services
  module Persistence
    class RepositoryPersistenceService
      extend T::Sig

      def self.persist_many(repositories)
        validate_bulk_input!(repositories)
        repos = repositories.map { |repo| Github::Repository.from_github(repo).stringify_keys }

        GithubRepository.upsert_all(
          repos,
          unique_by: :github_id,
          returning: false
        )
      end

      private

      sig { params(repositories: T::Array[Github::Repository]).void }
      def self.validate_bulk_input!(repositories)
        raise ArgumentError, "Repositories cannot be nil" if repositories.nil?
      end
    end
  end
end
