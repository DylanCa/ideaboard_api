module GithubRepositoryServices
  class PersistenceService
    class << self
      def update_repository_items(repo, prs, issues)
        ActiveRecord::Base.transaction do
          update_pull_requests(repo, prs) if prs.present?
          update_issues(repo, issues) if issues.present?
        end
      end

      def update_repositories_content(repositories, items)
        repositories.each_value do |repo|
          update_repository_items(
            repo,
            ProcessingService.filter_items_by_repo(items[:prs], repo.full_name),
            ProcessingService.filter_items_by_repo(items[:issues], repo.full_name)
          )
        end
      end

      private

      def update_pull_requests(repo, prs)
        return unless prs.present?
        Persistence::PullRequestPersistenceService.persist_many(prs, repo)
      end

      def update_issues(repo, issues)
        return unless issues.present?
        Persistence::IssuePersistenceService.persist_many(issues, repo)
      end
    end
  end
end
