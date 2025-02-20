module Queries
  module RepositoryQueries
    module Definitions
      RepositoryData = Github.client.parse <<~GRAPHQL
                query ($owner: String!, $name: String!) {
                  rateLimit {
                    cost
                    remaining
                    resetAt
                    limit
                    used
                  }
                  viewer {
                    login
                  }
                  repository(owner: $owner, name: $name) {
                    id
                    nameWithOwner
                    description
                    owner {
                      login
                    }
                    primaryLanguage {
                      name
                    }
                    isFork
                    stargazerCount
                    forkCount
                    isArchived
                    isDisabled
                    licenseInfo {
                      key
                    }
                    createdAt
                    updatedAt
                  }
                }
      GRAPHQL

      # Repository Pull Requests query - fetches paginated list of open PRs for a repository
      RepositoryPrs = Github.client.parse <<~GRAPHQL
                query ($owner: String!, $name: String!, $cursor: String) {
                  rateLimit {
                    cost
                    remaining
                    resetAt
                    limit
                    used
                  }
                  viewer {
                    login
                  }
                  repository(owner: $owner, name: $name) {
                    pullRequests(first: 100, states: OPEN, after: $cursor) {
                      pageInfo {
                        hasNextPage
                        endCursor
                      }
                      nodes {
                        id
                        title
                        url
                        number
                        state
                        author {
                          login
                        }
                        mergedAt
                        closedAt
                        createdAt
                        updatedAt
                        isDraft
                        totalCommentsCount
                        commits {
                          totalCount
                        }
                      }
                    }
                  }
                }
      GRAPHQL

      # Repository Issues query - fetches paginated list of open issues for a repository
      RepositoryIssues = Github.client.parse <<~GRAPHQL
                query ($owner: String!, $name: String!, $cursor: String) {
                  rateLimit {
                    cost
                    remaining
                    resetAt
                    limit
                    used
                  }
                  viewer {
                    login
                  }
                  repository(owner: $owner, name: $name) {
                    issues(first: 100, states: OPEN, after: $cursor) {
                      pageInfo {
                        hasNextPage
                        endCursor
                      }
                      nodes {
                        id
                        title
                        url
                        number
                        state
                        author {
                          login
                        }
                        createdAt
                        updatedAt
                        closedAt
                        comments {
                          totalCount
                        }
                      }
                    }
                  }
                }
      GRAPHQL
    end

    # Class methods to provide a clean interface for accessing the queries
    class << self
      def repository_data
        Definitions::RepositoryData
      end

      def repository_prs
        Definitions::RepositoryPrs
      end

      def repository_issues
        Definitions::RepositoryIssues
      end
    end
  end
end
