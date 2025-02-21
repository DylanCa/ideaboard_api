module Queries
  module GlobalQueries
    module Definitions
      SearchQuery = Github.client.parse <<~GRAPHQL
        query($query: String!, $cursor: String) {
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
          search(
            query: $query
            type: ISSUE
            first: 100
            after: $cursor
          ) {
            issueCount
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
                repository {
                  id
                  nameWithOwner
                }
                labels(first: 100) {
                  nodes {
                    name
                    color
                  }
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
                repository {
                  id
                  nameWithOwner
                }
                labels(first: 100) {
                  nodes {
                    name
                    color
                  }
                }
              }
            }
          }
        }
    GRAPHQL
    end

    class << self
      def search_query
        Definitions::SearchQuery
      end
    end
  end
end
