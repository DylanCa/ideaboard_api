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

      UserPRsData = Client.parse <<~GRAPHQL
        query {
          viewer {
            pullRequests(first: 100) {
              totalCount
              nodes {
                fullDatabaseId
                title
                url
              number
              state
              repository {
                databaseId
              }
              author {
                login
              }
              mergedAt
              closedAt
              createdAt
              updatedAt
              isDraft
              mergeable
              canBeRebased
              totalCommentsCount
              commits {
                totalCount
              }
              additions
              deletions
              changedFiles
              }
            }
          }
        }
      GRAPHQL

      UserIssuesData = Client.parse <<~GRAPHQL
        query {
          viewer {
            issues(first: 100) {
                totalCount
                nodes {
                    fullDatabaseId
                    title
                    url
                    number
                    state
                    repository {
                      databaseId
                    }
                    author {
                        login
                    }
                    reactions {
                        totalCount
                    }
                    comments {
                        totalCount
                    }
                    closedAt
                    createdAt
                    updatedAt
                }
            }
          }
        }
      GRAPHQL

      UserRepositoriesData = Client.parse <<~GRAPHQL
        query {
            viewer {
                repositories(first: 100) {
                    nodes {
                        id
                        name
                        nameWithOwner
                        description
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

      ### PAGINATION SECTION

      UserRepositories = Client.parse <<~GRAPHQL
      query($cursor: String) {
        viewer {
          repositories(
            affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER],
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
            }
          }
        }
      }
    GRAPHQL

      UserPullRequests = Client.parse <<~GRAPHQL
      query($cursor: String) {
        viewer {
          pullRequests(first: 100, after: $cursor) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              repository {
                id
              }
            }
          }
        }
      }
    GRAPHQL

      UserIssues = Client.parse <<~GRAPHQL
      query($cursor: String) {
        viewer {
          issues(first: 100, after: $cursor) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              repository {
                id
              }
            }
          }
        }
      }
    GRAPHQL


      RepositoriesData = ::Github::Client.parse <<~GRAPHQL
      query($repositoryIds: [ID!]!, $issuesCursor: String, $prsCursor: String) {
        nodes(ids: $repositoryIds) {
          ... on Repository {
            isPrivate
            id
            name
            nameWithOwner
            description
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
            issues(first: 100, after: $issuesCursor) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes  {
                    fullDatabaseId
                    title
                    url
                    number
                    state
                    author {
                        login
                    }
                    reactions {
                        totalCount
                    }
                    comments {
                        totalCount
                    }
                    closedAt
                    createdAt
                    updatedAt
                }
            }
            
            pullRequests(first: 100, after: $prsCursor) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes {
                fullDatabaseId
                title
                url
              number
              state
              repository {
                databaseId
              }
              author {
                login
              }
              mergedAt
              closedAt
              createdAt
              updatedAt
              isDraft
              mergeable
              canBeRebased
              totalCommentsCount
              commits {
                totalCount
              }
              additions
              deletions
              changedFiles
              }
            }
          }
        }
      }
    GRAPHQL
    end
  end
end
