  module Queries
    module UserQueries
      # We'll define our queries in a nested module to keep them organized and maintain proper scoping
      module Definitions
        # User Data query - fetches basic information about the authenticated user
        UserData = Github.client.parse <<~GRAPHQL
          query {
            rateLimit {
              remaining
              resetAt
            }
            viewer {
              databaseId
              email
              login
              avatarUrl
            }
          }
        GRAPHQL

        # User Repositories query - fetches paginated list of user's public repositories
        UserRepositories = Github.client.parse <<~GRAPHQL
          query($cursor: String) {
            rateLimit {
              remaining
              resetAt
            }
            viewer {
              repositories(
                privacy: PUBLIC,
                first: 100,
                after: $cursor
              ) {
                pageInfo {
                  hasNextPage
                  endCursor
                }
                nodes {
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
            }
          }
        GRAPHQL

        # Repository Data query - fetches detailed information about a specific repository
        RepositoryData = Github.client.parse <<~GRAPHQL
          query ($owner: String!, $name: String!) {
            rateLimit {
              remaining
              resetAt
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
          query ($owner: String!, $name: String!, $pr_cursor: String) {
            rateLimit {
              remaining
              resetAt
            }
            repository(owner: $owner, name: $name) {
              pullRequests(first: 100, states: OPEN, after: $pr_cursor) {
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
          query ($owner: String!, $name: String!, $issue_cursor: String) {
            rateLimit {
              remaining
              resetAt
            }
            repository(owner: $owner, name: $name) {
              issues(first: 100, states: OPEN, after: $issue_cursor) {
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
        def user_data
          Definitions::UserData
        end

        def user_repositories
          Definitions::UserRepositories
        end

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