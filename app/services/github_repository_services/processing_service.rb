module GithubRepositoryServices
  class ProcessingService
    class << self
      def process_contributions(items)
        repositories = ensure_repositories_exist(items[:repositories])
        PersistenceService.update_repositories_content(repositories, items)
      end

      def process_search_response(nodes, items)
        processed_repos = {}

        nodes.each do |node|
          case node.__typename
          when "PullRequest"
            if items[:repositories] && !processed_repos[node.repository.name_with_owner]
              items[:repositories] << node.repository
              processed_repos[node.repository.name_with_owner] = true
            end
            items[:prs] << node
          when "Issue"
            if items[:repositories] && !processed_repos[node.repository.name_with_owner]
              items[:repositories] << node.repository
              processed_repos[node.repository.name_with_owner] = true
            end
            items[:issues] << node
          when "Repository"
            if items[:repositories] && !processed_repos[node.name_with_owner]
              items[:repositories] << node
              processed_repos[node.name_with_owner] = true
            end
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
