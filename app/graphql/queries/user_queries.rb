module Queries
  module UserQueries
    module Definitions
      UserData = Github.client.parse <<~GRAPHQL
                query {
                  rateLimit {
                    cost
                    remaining
                    resetAt
                    limit
                    used
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
                    cost
                    remaining
                    resetAt
                    limit
                    used
                  }
                  viewer {
                    login
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
                        contributingGuidelines {
                          body
                          url
                        }
                        repositoryTopics(first: 100) {
                          nodes {
                            topic {
                              name
                            }
                          }
                        }
                        createdAt
                        updatedAt
                      }
                    }
                  }
                }
      GRAPHQL
    end

    class << self
      def user_data
        Definitions::UserData
      end

      def user_repositories
        Definitions::UserRepositories
      end
    end
  end
end
