module Processing
  class RepositoryProcessorService
    def self.update_repositories(repos)
      repos.each do |repo|
        prs = fetch_items(repo.full_name, item_type: :prs)
        issues = fetch_items(repo.full_name, item_type: :issues)
        update_repository_items(repo, prs, issues)
      end
    end

    def self.add_repo_by_name(repo_name)
      repo = fetch_repository(repo_name)
      return if repo.nil?

      Persistence::RepositoryPersistenceService.persist_many([ repo ])
    end

    def self.fetch_repository_update(repo)
      items = fetch_updates(repo.full_name, repo.last_polled_at_date)
      update_repository_items(repo, items[:prs], items[:issues])
    end

    private

    def self.fetch_repository(repo_name)
      owner, name = repo_name.split("/")
      variables = {
        owner: owner,
        name: name
      }

      response = Github::Helper.query_with_logs(Queries::UserQueries.repository_data, variables)
      response.data.repository
    end

    def self.update_repository_items(repo, prs, issues)
      update_pull_requests(repo, prs)
      update_issues(repo, issues)
      repo.update(last_polled_at: Time.current)
    end

    def self.update_pull_requests(repo, prs)
      return unless prs.present?

      Persistence::PullRequestPersistenceService.persist_many(prs, repo)
    end

    def self.update_issues(repo, issues)
      return unless issues.present?

      Persistence::IssuePersistenceService.persist_many(issues, repo)
    end

    def self.fetch_items(repo_full_name, item_type: :prs)
      owner, name = repo_full_name.split("/")

      variables = {
        owner: owner,
        name: name,
        cursor: nil
      }

      items = []

      loop do
        begin
          query = item_type == :prs ?
                    Queries::UserQueries.repository_prs :
                    Queries::UserQueries.repository_issues

          response = Github::Helper.query_with_logs(query, variables)

          collection = item_type == :prs ?
                         response.data.repository.pull_requests :
                         response.data.repository.issues

          collection.nodes.each { |item| items << item }

          page_info = collection.page_info
          break unless page_info.has_next_page

          variables[:cursor] = page_info.end_cursor
        rescue StandardError => e
          Rails.logger.error "Fetch #{item_type} error: #{e.message}"
        end
      end

      items
    end

    def self.fetch_updates(repo_full_name, last_synced_at)
      raise ArgumentError, "repo_full_name cannot be nil" if repo_full_name.nil?
      raise ArgumentError, "last_synced_at cannot be nil" if last_synced_at.nil?

      items = { prs: [], issues: [] }

      query = Queries::UserQueries.fetch_repository_updates
      variables = { query: "repo:#{repo_full_name} updated:>#{last_synced_at}", cursor: nil }

      loop do
        response = Github::Helper.query_with_logs(query, variables)
        process_response(response, items)

        page_info = response.data.search.page_info
        break unless page_info.has_next_page

        variables[:cursor] = page_info.end_cursor
      end

      items
    end

    def self.process_response(response, items)
      response.data.search.nodes.each do |node|
        case node.__typename
        when 'PullRequest'
          items[:prs] << node
        when 'Issue'
          items[:issues] << node
        end
      end
    end
  end
end
