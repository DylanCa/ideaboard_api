# app/controllers/api/pull_requests_controller.rb
module Api
  class PullRequestsController < ApplicationController
    include Api::Concerns::JwtAuthenticable
    skip_before_action :authenticate_user!, only: [ :show, :repository_pull_requests ]

    # GET /api/pull_requests/:id
    def show
      pull_request = PullRequest.find_by(id: params[:id])
      return render_error("Pull request not found", :not_found) if pull_request.nil?

      render_pull_request_with_related_data(pull_request)
    end

    # GET /api/repositories/:repository_id/pull_requests
    def repository_pull_requests
      repository = GithubRepository.find_by(id: params[:id])
      return render_error("Repository not found", :not_found) if repository.nil?
      pull_requests = repository.pull_requests
                                 .order(github_created_at: :desc)
                                 .page(params[:page] || 1)
                                 .per(params[:per_page] || 20)

      # Apply filters if provided
      pull_requests = apply_pull_request_filters(pull_requests)



      render_success(
        {
          pull_requests: pull_requests
      },
        {
          total_count: pull_requests.total_count,
          current_page: pull_requests.current_page,
          total_pages: pull_requests.total_pages
        }
      )
    end

    # GET /api/users/pull_requests
    def user_pull_requests
      pull_requests = PullRequest.where(author_username: current_user.github_username)
                                  .includes(:github_repository, :labels)
                                  .order(github_created_at: :desc)
                                  .page(params[:page] || 1)
                                  .per(params[:per_page] || 20)

      # Apply filters if provided
      pull_requests = apply_pull_request_filters(pull_requests)

      render_success(
        {
          pull_requests: pull_requests.as_json(include: [ :github_repository, :labels ])
        },
        {
          total_count: pull_requests.total_count,
          current_page: pull_requests.current_page,
          total_pages: pull_requests.total_pages
        }
      )
    end

    private

    def apply_pull_request_filters(query)
      # Filter by state
      if params[:state].present?
        case params[:state]
        when "open"
          query = query.open
        when "closed"
          query = query.closed
        when "merged"
          query = query.merged
        when "draft"
          query = query.where(is_draft: true)
        end
      end

      # Filter by labels
      if params[:labels].present?
        label_names = params[:labels].split(",")
        query = query.joins(:labels).where(labels: { name: label_names }).distinct
      end

      # Filter by date range
      if params[:since].present?
        query = query.where("pull_requests.github_created_at >= ?", params[:since])
      end

      query
    end

    def render_pull_request_with_related_data(pull_request)
      render_success({
        pull_request: pull_request.as_json(include: [ :labels ]),
        repository: pull_request.github_repository
      })
    end
  end
end
