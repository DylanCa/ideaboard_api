module Api
  class RepositoriesController < ApplicationController
    include JwtAuthenticable
    skip_before_action :authenticate_user!, only: [ :index, :show, :trending, :featured ]
    before_action :set_repository, only: [ :show, :qualification, :visibility, :update_data ]
    before_action :check_repository_ownership, only: [ :visibility ]

    # GET /api/repositories
    def index
      @repositories = GithubRepository.visible.by_stars
                                      .page(params[:page] || 1)
                                      .per(params[:per_page] || 20)

      if params[:language].present?
        @repositories = @repositories.with_language(params[:language])
      end

      if params[:topic].present?
        @repositories = @repositories.joins(:topics).where(topics: { name: params[:topic] })
      end

      render json: {
        repositories: @repositories,
        meta: {
          total_count: @repositories.total_count,
          current_page: @repositories.current_page,
          total_pages: @repositories.total_pages
        }
      }
    end

    # GET /api/repositories/:id
    def show
      # Get all labels for this repository's issues and PRs
      labels = Label.where(github_repository_id: @repository.id).distinct

      render json: {
        repository: @repository,
        topics: @repository.topics,
        labels: labels
      }
    end

    # POST /api/repositories
    def create
      repo_name = params[:repository_full_name]

      if GithubRepository.exists?(full_name: repo_name)
        render json: { message: "Repository already exists", repository: GithubRepository.find_by(full_name: repo_name) }
        return
      end

      RepositoryDataFetcherWorker.perform_async(repo_name)

      render json: {
        message: "Repository add job started",
        repository_name: repo_name
      }, status: :accepted
    end

    # GET /api/repositories/trending
    def trending
      # Using metrics like recent stars, PR activity, and issue activity to calculate trending
      @repositories = GithubRepository.visible
                                      .where("github_updated_at > ?", 7.days.ago)
                                      .joins("LEFT JOIN pull_requests ON pull_requests.github_repository_id = github_repositories.id AND pull_requests.github_created_at > '#{30.days.ago.iso8601}'")
                                      .joins("LEFT JOIN issues ON issues.github_repository_id = github_repositories.id AND issues.github_created_at > '#{30.days.ago.iso8601}'")
                                      .group("github_repositories.id")
                                      .order("COUNT(pull_requests.id) + COUNT(issues.id) DESC, github_repositories.stars_count DESC")
                                      .page(params[:page] || 1)
                                      .per(params[:per_page] || 20)

      render json: {
        repositories: @repositories,
        meta: {
          total_count: @repositories.total_count,
          current_page: @repositories.current_page,
          total_pages: @repositories.total_pages
        }
      }
    end

    # GET /api/repositories/featured
    def featured
      # For MVP, featured can be a curated list of high-quality repos
      # Later this could be editorially selected
      @repositories = GithubRepository.visible
                                      .where(has_contributing: true)
                                      .where("stars_count > ?", 100)
                                      .order(stars_count: :desc)
                                      .limit(10)

      render json: { repositories: @repositories }
    end

    # GET /api/repositories/:id/qualification
    def qualification
      qualification_result = {
        has_license: @repository.license.present?,
        has_contributing: @repository.has_contributing,
        is_active: @repository.github_updated_at > 3.months.ago,
        has_open_issues: @repository.issues.open.exists?,
        is_not_archived: !@repository.archived,
        is_not_disabled: !@repository.disabled,
        qualifies: false
      }

      # Determine if repository qualifies for contribution
      qualification_result[:qualifies] = (
        qualification_result[:has_license] &&
          qualification_result[:has_contributing] &&
          qualification_result[:is_active] &&
          qualification_result[:has_open_issues] &&
          qualification_result[:is_not_archived] &&
          qualification_result[:is_not_disabled]
      )

      render json: { qualification: qualification_result }
    end

    # PUT /api/repositories/:id/visibility
    def visibility
      @repository.update(visible: params[:visible])
      render json: { repository: @repository }
    end

    # POST /api/repositories/:id/update_data
    def update_data
      RepositoryUpdateWorker.perform_async(@repository.full_name)

      render json: {
        message: "Repository update job started",
        repository_id: @repository.id
      }, status: :accepted
    end

    # POST /api/repositories/refresh_all
    def refresh
      # This action requires authentication
      return render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user

      # Start the background job to refresh all repositories
      Github::GraphqlService.update_repositories_data

      render json: {
        message: "Repository refresh job started for all repositories",
        status: "processing"
      }, status: :accepted
    end

    private

    def set_repository
      @repository = GithubRepository.find_by(id: params[:id]) ||
        GithubRepository.find_by(full_name: params[:id])

      unless @repository
        render json: { error: "Repository not found" }, status: :not_found
      end
    end

    def check_repository_ownership
      unless @current_user.github_account.github_username == @repository.author_username
        render json: { error: "You don't have permission to modify this repository" },
               status: :unauthorized
      end
    end
  end
end
