module Github
  module Queries
    module UserQueries
      UserData = Client.parse <<~GRAPHQL
        query {
            viewer {
                databaseId
                email
                login
                avatarUrl
            }
        }
      GRAPHQL

      UserRepositories = Client.parse <<~GRAPHQL
        query($cursor: String) {
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
                  defaultBranchRef {
                      target {
                          ... on Commit {
                              history(first: 0) {
                                  totalCount
                              }
                          }
                      }
                  }
              }
            }
          }
        }
      GRAPHQL

      RepositoryData = ::Github::Client.parse <<~GRAPHQL
        query($query: String!, $cursor: String) {
          rateLimit {
            remaining
            resetAt
          }
          search(
            query: $query
            type: REPOSITORY
            first: 100
            after: $cursor
          ) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              ... on Repository {
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
                  defaultBranchRef {
                      target {
                          ... on Commit {
                              history(first: 0) {
                                  totalCount
                              }
                          }
                      }
                  }
              }
            }
          }
        }
      GRAPHQL

      RepositoriesItems = ::Github::Client.parse <<~GRAPHQL
        query($query: String!, $cursor: String) {
          rateLimit {
            remaining
            resetAt
          }
          search(
            query: $query
            type: ISSUE
            first: 100
            after: $cursor
          ) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              ... on PullRequest {
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
              ... on Issue {
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
  end
end
