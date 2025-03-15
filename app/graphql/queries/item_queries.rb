module Queries
  module ItemQueries
    module Definitions
      SpecificPullRequest = Github.client.parse <<~GRAPHQL
        query ($owner: String!, $name: String!, $number: Int!) {
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
            pullRequest(number: $number) {
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
              closingIssuesReferences(first: 100) {
                nodes {
                  number
                  repository {
                    nameWithOwner
                  }
                }
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
      GRAPHQL

      SpecificIssue = Github.client.parse <<~GRAPHQL
        query ($owner: String!, $name: String!, $number: Int!) {
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
            issue(number: $number) {
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
              closedByPullRequestsReferences(first: 100) {
                nodes {
                  number
                  repository {
                    nameWithOwner
                  }
                }
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
      GRAPHQL
    end

    class << self
      def specific_pull_request
        Definitions::SpecificPullRequest
      end

      def specific_issue
        Definitions::SpecificIssue
      end
    end
  end
end
