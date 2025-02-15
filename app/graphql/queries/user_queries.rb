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
                rateLimit {
                  remaining
                  resetAt
                }
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

      RepositoryData = ::Github::Client.parse <<~GRAPHQL
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

      RepositoryPrs = ::Github::Client.parse <<~GRAPHQL
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

      RepositoryIssues = ::Github::Client.parse <<~GRAPHQL
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
  end
end
