module GithubRepositoryServices
  class ProcessingService
    class << self
      def process_contributions(items)
        repositories = ensure_repositories_exist(items[:repositories])
        PersistenceService.update_repositories_content(repositories, items)
      end

      def process_search_response(nodes, items)
        nodes.each do |node|
          items[:repositories] << node.repository unless items[:repositories].nil?

          case node.__typename
          when "PullRequest"
            items[:prs] << node
          when "Issue"
            items[:issues] << node
          end
        end
      end

      def filter_items_by_repo(items, repo_name)
        items.select { |item| item.repository.name_with_owner == repo_name }
      end

      private

      def ensure_repositories_exist(repositories)
        existing_repos = fetch_existing_repositories(repositories)

        repositories.each do |repo|
          next if existing_repos.key?(repo.name_with_owner)
          RepositoryFetcherWorker.perform_async(repo.name_with_owner)
        end

        fetch_existing_repositories(repositories)
      end

      def fetch_existing_repositories(repositories)
        GithubRepository.where(
          full_name: repositories.map(&:name_with_owner)
        ).index_by(&:full_name)
      end
    end
  end
end
