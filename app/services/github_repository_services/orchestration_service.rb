module GithubRepositoryServices
  class OrchestrationService
    class << self
      # Public Interface Methods
      def update_repositories(repos)
        repos.each do |repo|
          prs = QueryService.fetch_items(repo.full_name, item_type: :prs)
          issues = QueryService.fetch_items(repo.full_name, item_type: :issues)
          PersistenceService.update_repository_items(repo, prs, issues)
        end
      end

      def add_repo_by_name(repo_name)
        repo = QueryService.fetch_repository(repo_name)
        return if repo.nil?

        Persistence::RepositoryPersistenceService.persist_many([ repo ])
      end

      def fetch_repository_update(repo)
        items = QueryService.fetch_updates(repo.full_name, repo.last_polled_at_date)
        PersistenceService.update_repository_items(repo, items[:prs], items[:issues])
      end

      def fetch_user_contributions(user)
        items = { repositories: Set.new, prs: [], issues: [] }

        [ :prs, :issues ].each do |contrib_type|
          QueryService.fetch_user_contribution_type(user, items, contrib_type)
        end

        ProcessingService.process_contributions(items)
      end
    end
  end
end
