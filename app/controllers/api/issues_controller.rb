# app/controllers/api/issues_controller.rb
module Api
  class IssuesController < ApplicationController
    include Api::Concerns::JwtAuthenticable
    skip_before_action :authenticate_user!, only: [ :show, :repository_issues ]

    # GET /api/issues/:id
    def show
      @issue = Issue.find(params[:id])
      render_issue_with_related_data(@issue)
    rescue ActiveRecord::RecordNotFound
      render_error("Issue not found", :not_found)
    end

    # GET /api/repositories/:repository_id/issues
    def repository_issues
      repository = GithubRepository.find(params[:id])
      @issues = repository.issues
                          .order(github_created_at: :desc)
                          .page(params[:page] || 1)
                          .per(params[:per_page] || 20)

      # Apply filters if provided
      @issues = apply_issue_filters(@issues)

      render_success(
        {
          issues: @issues
        },
        {
          total_count: @issues.total_count,
          current_page: @issues.current_page,
          total_pages: @issues.total_pages
        }
      )
    rescue ActiveRecord::RecordNotFound
      render_error("Repository not found", :not_found)
    end

    # GET /api/users/issues
    def user_issues
      @issues = Issue.where(author_username: @current_user.github_username)
                     .includes(:github_repository, :labels)
                     .order(github_created_at: :desc)
                     .page(params[:page] || 1)
                     .per(params[:per_page] || 20)

      # Apply filters if provided
      @issues = apply_issue_filters(@issues)

      render_success(
        {
          issues: @issues.as_json(include: [ :github_repository, :labels ])
        },
        {
          total_count: @issues.total_count,
          current_page: @issues.current_page,
          total_pages: @issues.total_pages
        }
      )
    end

    private

    def apply_issue_filters(query)
      # Filter by state
      if params[:state].present?
        case params[:state]
        when "open"
          query = query.open
        when "closed"
          query = query.closed
        end
      end

      # Filter by labels
      if params[:labels].present?
        label_names = params[:labels].split(",")
        query = query.joins(:labels).where(labels: { name: label_names }).distinct
      end

      # Filter by date range
      if params[:since].present?
        query = query.where("issues.github_created_at >= ?", params[:since])
      end

      query
    end

    def render_issue_with_related_data(issue)
      render_success({
        issue: issue.as_json(include: [ :labels ]),
        repository: issue.github_repository
      })
    end
  end
end
