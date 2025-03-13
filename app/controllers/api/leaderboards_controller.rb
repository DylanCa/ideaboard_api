# app/controllers/api/leaderboards_controller.rb
module Api
  class LeaderboardsController < ApplicationController
    include Api::Concerns::JwtAuthenticable
    skip_before_action :authenticate_user!
    before_action :set_repository, only: [ :repository ]

    # GET /api/leaderboards/global
    def global
      # Query top contributors based on reputation points
      leaderboard = UserStat.includes(user: :github_account)
                            .active_contributors
                            .top_contributors
                            .limit(params[:limit] || 100)
                            .page(params[:page] || 1)
                            .per(params[:per_page] || 20)

      # Calculate ranks based on reputation points
      ranked_leaderboard = leaderboard.map.with_index do |stat, index|
        format_user_stat(stat, index + 1)
      end


      render_success(
        {
          leaderboard: ranked_leaderboard
        },
        {
          total_count: leaderboard.total_count,
          current_page: leaderboard.current_page,
          total_pages: leaderboard.total_pages
        }
      )
    end

    # GET /api/leaderboards/repository/:id
    def repository
      # Query top contributors for this repository
      leaderboard = UserRepositoryStat.where(github_repository_id: @repository.id)
                                      .includes(user: [ :github_account, :user_stat ])
                                      .order(merged_prs_count: :desc)
                                      .page(params[:page] || 1)
                                      .per(params[:per_page] || 20)

      # Calculate ranks based on merged PRs and reputation points
      ranked_leaderboard = leaderboard.map.with_index do |stat, index|
        format_repository_stat(stat, index + 1)
      end


      render_success(
        {
          repository: @repository.full_name,
          leaderboard: ranked_leaderboard        },
        {
          total_count: leaderboard.total_count,
          current_page: leaderboard.current_page,
          total_pages: leaderboard.total_pages
        }
      )
    end

    private

    def set_repository
      @repository = GithubRepository.find_by(id: params[:id]) ||
        GithubRepository.find_by(full_name: params[:id])

      unless @repository
        render_error("Repository not found", :not_found)
      end
    end

    def format_user_stat(stat, rank)
      {
        user_id: stat.user_id,
        username: stat.user.github_account&.github_username,
        avatar_url: stat.user.github_account&.avatar_url,
        reputation_points: stat.reputation_points,
        rank: rank
      }
    end

    def format_repository_stat(stat, rank)
      {
        user_id: stat.user_id,
        username: stat.user.github_account&.github_username,
        avatar_url: stat.user.github_account&.avatar_url,
        opened_prs_count: stat.opened_prs_count,
        merged_prs_count: stat.merged_prs_count,
        issues_opened_count: stat.issues_opened_count,
        issues_closed_count: stat.issues_closed_count,
        first_contribution_at: stat.first_contribution_at,
        last_contribution_at: stat.last_contribution_at,
        reputation_points: stat.user.user_stat&.reputation_points || 0,
        rank: rank
      }
    end
  end
end
