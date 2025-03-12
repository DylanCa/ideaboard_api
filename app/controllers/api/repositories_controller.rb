module Api
  class RepositoriesController < ApplicationController
    include Api::Concerns::JwtAuthenticable
    skip_before_action :authenticate_user!, only: [ :index, :show, :trending, :featured ]
    before_action :set_repository, only: [ :show, :qualification, :visibility, :update_data, :health, :activity ]
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

    # GET /api/repositories/search
    def search
      # Get parameters with defaults
      @query = params[:q] || ""
      @page = params[:page] || 1
      @per_page = params[:per_page] || 20
      @sort = params[:sort] || "stars"
      @language = params[:language]
      @topic = params[:topic]

      # Base query
      @repositories = GithubRepository.visible.where("full_name ILIKE ? OR description ILIKE ?",
                                                     "%#{@query}%", "%#{@query}%")

      # Apply filters
      @repositories = @repositories.with_language(@language) if @language.present?
      @repositories = @repositories.joins(:topics).where(topics: { name: @topic }) if @topic.present?

      # Apply sorting
      case @sort
      when "stars"
        @repositories = @repositories.order(stars_count: :desc)
      when "forks"
        @repositories = @repositories.order(forks_count: :desc)
      when "recent"
        @repositories = @repositories.order(github_updated_at: :desc)
      when "created"
        @repositories = @repositories.order(github_created_at: :desc)
      end

      # Paginate
      @repositories = @repositories.page(@page).per(@per_page)

      render json: {
        repositories: @repositories,
        meta: {
          total_count: @repositories.total_count,
          current_page: @repositories.current_page,
          total_pages: @repositories.total_pages,
          query: @query
        }
      }
    end

    def recommendations
      unless @current_user
        return render json: { error: "Authentication required for personalized recommendations" },
                      status: :unauthorized
      end

      contributed_repo_ids = UserRepositoryStat.where(user_id: @current_user.id)
                                               .pluck(:github_repository_id)

      contributed_repos = GithubRepository.where(id: contributed_repo_ids)

      # Get languages and topics
      languages = contributed_repos.pluck(:language).compact.uniq

      topic_ids = GithubRepositoryTopic.where(github_repository_id: contributed_repo_ids)
                                       .pluck(:topic_id)

      # Find repositories with similar languages or topics using SQL UNION approach
      language_repos = GithubRepository.visible
                                       .where.not(id: contributed_repo_ids)
                                       .where(language: languages)
                                       .pluck(:id)

      topic_repos = GithubRepository.visible
                                    .where.not(id: contributed_repo_ids)
                                    .joins(:github_repository_topics)
                                    .where(github_repository_topics: { topic_id: topic_ids })
                                    .pluck(:id)

      # Combine both sets of IDs
      combined_repo_ids = (language_repos + topic_repos).uniq

      @recommendations = GithubRepository.where(id: combined_repo_ids)
                                         .order(stars_count: :desc)
                                         .page(params[:page] || 1)
                                         .per(params[:per_page] || 20)

      per_page = params[:per_page] ? params[:per_page].to_i : 20

      render json: {
        repositories: @recommendations,
        meta: {
          total_count: @recommendations.count,
          current_page: params[:page] || 1,
          total_pages: (@recommendations.count.to_f / per_page).ceil,
          based_on: {
            languages: languages,
            topics: Topic.where(id: topic_ids).pluck(:name)
          }
        }
      }
    end

    # GET /api/repositories/needs_help
    def needs_help
      # TODO: to improve
      # Find repositories that need help based on:
      # 1. Open issues to contributor ratio
      # 2. Not updated recently
      # 3. Few recent PRs

      @repositories = GithubRepository.visible
                                      .joins("LEFT JOIN issues ON issues.github_repository_id = github_repositories.id AND issues.closed_at IS NULL")
                                      .group("github_repositories.id")
                                      .having("COUNT(issues.id) > 0")  # Has open issues
                                      .where("github_repositories.github_updated_at < ?", 30.days.ago)  # Not updated recently
                                      .or(
                                        GithubRepository.visible
                                                        .joins("LEFT JOIN issues ON issues.github_repository_id = github_repositories.id AND issues.closed_at IS NULL")
                                                        .group("github_repositories.id")
                                                        .having("COUNT(issues.id) / (github_repositories.stars_count + 1) > 0.05")  # High open issue to star ratio
                                      )
                                      .order("COUNT(issues.id) DESC")
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

    # GET /api/repositories/:id/health
    def health
      return render json: { error: "Repository not found" }, status: :not_found unless @repository

      health_metrics = {
        # Basic repo stats
        stars_count: @repository.stars_count,
        forks_count: @repository.forks_count,

        # Qualification metrics
        has_license: @repository.license.present?,
        has_contributing: @repository.has_contributing,
        is_active: @repository.github_updated_at > 3.months.ago,
        is_not_archived: !@repository.archived,
        is_not_disabled: !@repository.disabled,

        # Additional health metrics
        contributor_count: calculate_contributor_count(@repository),
        pr_velocity: calculate_pr_velocity(@repository),
        issue_response_time: calculate_issue_response_time(@repository),
        pr_merge_rate: calculate_pr_merge_rate(@repository),

        # Overall health score
        health_score: calculate_health_score(@repository)
      }

      render json: { health: health_metrics }
    end

    # GET /api/repositories/:id/activity
    def activity
      return render json: { error: "Repository not found" }, status: :not_found unless @repository


      # Get recent activities (PRs, issues)
      recent_prs = @repository.pull_requests
                              .where("github_created_at > ? OR github_updated_at > ?", 30.days.ago, 30.days.ago)
                              .order(github_updated_at: :desc)
                              .limit(20)

      recent_issues = @repository.issues
                                 .where("github_created_at > ? OR github_updated_at > ?", 30.days.ago, 30.days.ago)
                                 .order(github_updated_at: :desc)
                                 .limit(20)

      # Combine and format activities
      activities = format_activities(recent_prs, recent_issues)

      render json: {
        repository_id: @repository.id,
        repository_name: @repository.full_name,
        activities: activities
      }
    end

    def topics
      @repository = GithubRepository.find_by(id: params[:id]) ||
        GithubRepository.find_by(full_name: params[:id])

      if @repository
        @topics = @repository.topics
        render json: {
          repository: { id: @repository.id, full_name: @repository.full_name },
          topics: @topics
        }
      else
        render json: { error: "Repository not found" }, status: :not_found
      end
    end

    private

    # Helper methods for health metrics
    def calculate_contributor_count(repository)
      PullRequest.where(github_repository_id: repository.id)
                 .select(:author_username)
                 .distinct
                 .count
    end

    def calculate_pr_velocity(repository)
      prs_last_month = repository.pull_requests
                                 .where("merged_at > ?", 30.days.ago)
                                 .count

      (prs_last_month * 7 / 30.0).round(1) # PRs per week
    end

    def calculate_issue_response_time(repository)
      recently_closed_issues = repository.issues
                                         .where("closed_at > ?", 90.days.ago)
                                         .where.not(closed_at: nil)

      return nil if recently_closed_issues.empty?

      total_days = recently_closed_issues.sum do |issue|
        (issue.closed_at.to_date - issue.github_created_at.to_date).to_i
      end

      (total_days.to_f / recently_closed_issues.count).round(1)
    end

    def calculate_pr_merge_rate(repository)
      recent_prs = repository.pull_requests
                             .where("github_created_at > ?", 90.days.ago)

      return nil if recent_prs.empty?

      merged_prs = recent_prs.where.not(merged_at: nil).count
      ((merged_prs.to_f / recent_prs.count) * 100).round(1)
    end

    def calculate_health_score(repository)
      score = 0

      # Basic qualification factors
      score += 20 if repository.license.present?
      score += 15 if repository.has_contributing
      score += 20 if repository.github_updated_at > 3.months.ago
      score -= 40 if repository.archived
      score -= 40 if repository.disabled

      # Activity factors
      open_issues_count = repository.issues.where(closed_at: nil).count
      score += 15 if open_issues_count > 0
      score += 10 if calculate_pr_merge_rate(repository).to_f > 50

      # Popularity factors
      score += [ repository.stars_count / 100, 10 ].min
      score += [ repository.forks_count / 10, 10 ].min

      [ score, 100 ].min
    end

    def format_activities(prs, issues)
      activities = []

      prs.each do |pr|
        activities << {
          type: "pull_request",
          id: pr.id,
          title: pr.title,
          url: pr.url,
          author: pr.author_username,
          created_at: pr.github_created_at,
          updated_at: pr.github_updated_at,
          state: pr.state
        }
      end

      issues.each do |issue|
        activities << {
          type: "issue",
          id: issue.id,
          title: issue.title,
          url: issue.url,
          author: issue.author_username,
          created_at: issue.github_created_at,
          updated_at: issue.github_updated_at,
          closed_at: issue.closed_at
        }
      end

      activities.sort_by { |activity| activity[:updated_at] }.reverse
    end

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
