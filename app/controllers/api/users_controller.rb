module Api
  class UsersController < ApplicationController
    include Api::Concerns::JwtAuthenticable

    def current_user
      result = Github::GraphqlService.fetch_current_user_data(@current_user)
      render_success(result, {}, :ok)
    end

    def user_repos
      result = Github::GraphqlService.fetch_current_user_repositories(@current_user)
      render_success(result, {}, :ok)
    end

    def fetch_user_contributions
      result = Github::GraphqlService.fetch_user_contributions(@current_user)
      render_success(result, {}, :ok)
    end

    def profile
      render_success(
        {
          user: @current_user,
          github_account: @current_user.github_account,
          user_stat: @current_user.user_stat
        }
      )
    end

    def update_profile
      allowed_params = profile_params

      if @current_user.update(allowed_params.slice(:email))
        if allowed_params[:token_usage_level].present?
          @current_user.update(token_usage_level: allowed_params[:token_usage_level])
        end

        render_success({
          user: @current_user,
          github_account: @current_user.github_account,
          user_stat: @current_user.user_stat
        })
      else
        render_error("Failed", :unprocessable_entity, { errors: @current_user.errors.full_messages })
      end
    end

    def reputation_timeline
      page = params[:page] || 1
      per_page = params[:per_page] || 20

      @events = @current_user.reputation_events
                             .includes(:github_repository, :pull_request, :issue)
                             .order(occurred_at: :desc)
                             .page(page)
                             .per(per_page)

      render_success(
        {
          reputation_total: @current_user.user_stat&.reputation_points || 0,
          events: @events.map do |event|
            {
              id: event.id,
              description: event.description || event.generate_description,
              points_change: event.points_change,
              event_type: event.event_type,
              occurred_at: event.occurred_at,
              breakdown: event.points_breakdown,
              repository: event.github_repository&.full_name,
              pull_request_number: event.pull_request&.number,
              issue_number: event.issue&.number
            }
          end
        },
        {
          total_count: @events.total_count,
          current_page: @events.current_page,
          total_pages: @events.total_pages
        }
      )
    end

    private

    def profile_params
      params.require(:user).permit(:email, :token_usage_level)
    end
  end
end
