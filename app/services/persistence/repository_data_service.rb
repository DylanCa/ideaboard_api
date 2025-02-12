# app/services/persistence/repository_data_service.rb
module Services
  module Persistence
    class RepositoryDataService
      extend T::Sig

      REPOSITORIES_PER_QUERY = 20 # GitHub has a limit on nodes query

      sig { returns(String) }
      attr_reader :access_token

      sig { params(user_id: Integer, access_token: String).void }
      def initialize(user_id, access_token)
        @access_token = access_token
        @user_id = user_id
      end

      sig { params(repository_ids: T::Array[Integer]).void }
      def fetch_and_persist_repositories_data(repository_ids)
        # Split repository IDs into chunks to avoid hitting GitHub's node limit
        repository_ids.each_slice(REPOSITORIES_PER_QUERY) do |repo_ids_chunk|
          fetch_and_persist_chunk(repo_ids_chunk)
          puts 'sleeping before next chunk ...'
          sleep 5
        end
      end

      private

      sig { params(repository_ids: T::Array[Integer]).void }
      def fetch_and_persist_chunk(repository_ids)
        response = ::Github::Client.query(
          ::Github::Queries::UserQueries::RepositoriesData,
          variables: {
            repositoryIds: repository_ids.map { |id| id },
            issuesCursor: nil,
            prsCursor: nil
          },
          context: { token: access_token }
        )
        Rails.logger.info "GraphQL Response: #{response.inspect}"
        persist_repositories_data(response.data.nodes)
      end

      sig { params(repositories_data: T::Array[T::Hash[String, T.untyped]]).void }
      def persist_repositories_data(repositories_data)
        repositories_data.each do |repo_data|
          next if repo_data.nil? || repo_data.is_private # Skip private repositories

          repository = RepositoryPersistenceService.persist_repo_from_github(repo_data, @user_id)

          ActiveRecord::Base.transaction do
            # Fetch and persist all pull requests with pagination
            fetch_and_persist_all_pull_requests(repo_data.id, repository.id)
            # Fetch and persist all issues with pagination
            fetch_and_persist_all_issues(repo_data.id, repository.id)

          end
        end
      end

      sig { params(repo_node_id: String, github_repository_id: Integer).void }
      def fetch_and_persist_all_issues(repo_node_id, github_repository_id)
        issues_cursor = nil

        loop do
          response = ::Github::Client.query(
            ::Github::Queries::UserQueries::RepositoriesData,
            variables: {
              repositoryIds: [repo_node_id],
              issuesCursor: issues_cursor,
              prsCursor: nil
            },
            context: { token: access_token }
          )
          Rails.logger.info "GraphQL Response: #{response.inspect}"
          repo_data = response.data.nodes.first
          break unless repo_data&.issues

          IssuePersistenceService.persist_many(repo_data.issues.nodes, github_repository_id)

          page_info = repo_data.issues.page_info
          break unless page_info.has_next_page

          issues_cursor = page_info.end_cursor
        end
      end

      sig { params(repo_node_id: String, github_repository_id: Integer).void }
      def fetch_and_persist_all_pull_requests(repo_node_id, github_repository_id)
        prs_cursor = nil

        loop do
          response = ::Github::Client.query(
            ::Github::Queries::UserQueries::RepositoriesData,
            variables: {
              repositoryIds: [repo_node_id],
              issuesCursor: nil,
              prsCursor: prs_cursor
            },
            context: { token: access_token }
          )
          Rails.logger.info "GraphQL Response: #{response.inspect}"
          repo_data = response.data.nodes.first
          break unless repo_data&.pull_requests

          PullRequestPersistenceService.persist_many(repo_data.pull_requests.nodes, github_repository_id)

          page_info = repo_data.pull_requests.page_info
          break unless page_info.has_next_page

          prs_cursor = page_info.end_cursor
        end
      end

      def persist_repository(repo_data)
        # Find or create language
        language = Language.find_or_create_by!(name: repo_data.primary_language&.name) if repo_data.primary_language

        attributes = {
          github_id: repo_data.id,
          language_id: language&.id,
          name: repo_data.name,
          full_name: repo_data.name_with_owner,
          description: repo_data.description,
          is_fork: repo_data.is_fork,
          stars_count: repo_data.stargazer_count,
          forks_count: repo_data.fork_count,
          archived: repo_data.is_archived,
          disabled: repo_data.is_disabled,
          license_key: repo_data.license_info&.key,
          github_created_at: repo_data.created_at,
          github_updated_at: repo_data.updated_at
        }

        GithubRepository.find_or_initialize_by(github_id: repo_data.database_id).tap do |repo|
          repo.update!(attributes)
        end
      end

      def persist_issues(issues_data, github_repository_id)
        issues_data.each do |issue_data|
          attributes = {
            github_repository_id: github_repository_id,
            full_database_id: issue_data.database_id,
            title: issue_data.title,
            url: issue_data.url,
            number: issue_data.number,
            state: issue_data.state,
            author_username: issue_data.author&.login,
            comments_count: issue_data.comments.total_count,
            reactions_count: issue_data.reactions.total_count,
            github_created_at: issue_data.created_at,
            github_updated_at: issue_data.updated_at,
            closed_at: issue_data.closed_at
          }

          Issue.upsert(attributes, unique_by: :full_database_id)
        end
      end

      def persist_pull_requests(prs_data, github_repository_id)
        prs_data.each do |pr_data|
          attributes = {
            github_repository_id: github_repository_id,
            full_database_id: pr_data.database_id,
            title: pr_data.title,
            url: pr_data.url,
            number: pr_data.number,
            state: pr_data.state,
            author_username: pr_data.author&.login,
            merged_at: pr_data.merged_at,
            closed_at: pr_data.closed_at,
            github_created_at: pr_data.created_at,
            github_updated_at: pr_data.updated_at,
            is_draft: pr_data.is_draft,
            mergeable: pr_data.mergeable,
            can_be_rebased: pr_data.can_be_rebased,
            total_comments_count: pr_data.total_comments_count,
            commits: pr_data.commits.total_count,
            additions: pr_data.additions,
            deletions: pr_data.deletions,
            changed_files: pr_data.changed_files
          }

          PullRequest.upsert(attributes, unique_by: :full_database_id)
        end
      end
    end
  end
end