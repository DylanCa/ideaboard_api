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
                        databaseId
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
    end
  end
end
