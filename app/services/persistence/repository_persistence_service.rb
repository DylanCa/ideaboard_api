require_relative "../../models/github/repository"

module Services
  module Persistence
    class RepositoryPersistenceService
      extend T::Sig

      sig { params(repositories: T::Array[Github::Repository], user_id: Integer).void }
      def self.persist_many(repositories, user_id)
        validate_bulk_input!(repositories, user_id)

        # Pre-load or create all languages at once
        language_names = repositories.map { |r| r.primary_language&.downcase }.compact.uniq
        languages_by_name = bulk_find_or_create_languages(language_names)

        # Prepare attributes for all repositories
        attributes_list = repositories.map do |repository|
          {
            user_id: user_id,
            language_id: languages_by_name[repository.primary_language&.downcase]&.id,
            github_id: repository.github_id,
            name: repository.name,
            full_name: repository.name_with_owner,
            description: repository.description,
            is_fork: repository.is_fork,
            stars_count: repository.stars_count,
            forks_count: repository.forks_count,
            archived: repository.archived,
            disabled: repository.disabled,
            license_key: repository.license,
            total_commits_count: repository.total_commits_count,
            visible: true, # Default to visible
            github_created_at: repository.github_created_at,
            github_updated_at: repository.github_updated_at
          }
        end

        # Perform bulk upsert
        GithubRepository.upsert_all(
          attributes_list,
          unique_by: :github_id,
        )
      end

      def self.persist_repo_from_github(repository, user_id)
        raise ArgumentError, "Repositories cannot be nil" if repository.nil?
        raise ArgumentError, "User ID cannot be nil" if user_id.nil?

        repository = Github::Repository.from_github(repository)

        # Pre-load or create all languages at once
        languages_by_name = bulk_find_or_create_languages([ repository.primary_language&.downcase ].compact.uniq)
        language_id = languages_by_name[repository.primary_language&.downcase]&.id

        # Prepare attributes for all repositories
        attributes = {
            user_id: user_id,
            language_id: language_id,
            github_id: repository.github_id,
            name: repository.name,
            full_name: repository.name_with_owner,
            description: repository.description,
            is_fork: repository.is_fork,
            stars_count: repository.stars_count,
            forks_count: repository.forks_count,
            archived: repository.archived,
            disabled: repository.disabled,
            license_key: repository.license,
            total_commits_count: repository.total_commits_count,
            visible: true, # Default to visible
            github_created_at: repository.github_created_at,
            github_updated_at: repository.github_updated_at
          }

        GithubRepository.find_or_initialize_by(github_id: repository.github_id).tap do |repo|
          repo.update!(attributes)
        end
      end

      private

      sig { params(repositories: T::Array[Github::Repository], user_id: Integer).void }
      def self.validate_bulk_input!(repositories, user_id)
        raise ArgumentError, "Repositories cannot be nil" if repositories.nil?
        raise ArgumentError, "User ID cannot be nil" if user_id.nil?
      end

      def self.bulk_find_or_create_languages(language_names)
        return {} if language_names.empty?

        # Find existing languages
        existing_languages = Language.where(name: language_names)
        existing_by_name = existing_languages.index_by(&:name)

        # Create missing languages
        missing_names = (language_names - existing_by_name.keys).compact.uniq
        return existing_by_name if missing_names.empty?

        created_languages = Language.create!(missing_names.map { |name| { name: name } })
        created_by_name = created_languages.index_by(&:name)

        existing_by_name.merge(created_by_name)
      end
    end
  end
end
