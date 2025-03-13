# app/controllers/api/repository_stats_controller.rb
module Api
  class RepositoryStatsController < ApplicationController
    include Api::Concerns::JwtAuthenticable

    def index
      # Get all repository stats for the current user
      @stats = UserRepositoryStat.where(user_id: @current_user.id)
                                 .includes(:github_repository)
                                 .order(last_contribution_at: :desc)
                                 .page(params[:page] || 1)
                                 .per(params[:per_page] || 20)

      render json: {
        repository_stats: format_stats(@stats),
        meta: {
          total_count: @stats.total_count,
          current_page: @stats.current_page,
          total_pages: @stats.total_pages
        }
      }
    end

    def show
      repository = GithubRepository.find(params[:id])
      @stats = UserRepositoryStat.find_by(user_id: @current_user.id, github_repository_id: repository.id)

      if @stats
        render_success({ repository_stats: format_stat(@stats, repository) }, {}, :ok)
      else
        render_error("No contribution statistics found for this repository", :not_found)
      end
    end

    private

    def format_stats(stats)
      stats.map { |stat| format_stat(stat, stat.github_repository) }
    end

    def format_stat(stat, repository)
      {
        id: stat.id,
        repository: {
          id: repository.id,
          full_name: repository.full_name,
          description: repository.description
        },
        stats: {
          opened_prs_count: stat.opened_prs_count,
          merged_prs_count: stat.merged_prs_count,
          closed_prs_count: stat.closed_prs_count,
          issues_opened_count: stat.issues_opened_count,
          issues_closed_count: stat.issues_closed_count,
          issues_with_pr_count: stat.issues_with_pr_count,
          contribution_streak: stat.contribution_streak,
          first_contribution_at: stat.first_contribution_at,
          last_contribution_at: stat.last_contribution_at
        }
      }
    end
  end
end
