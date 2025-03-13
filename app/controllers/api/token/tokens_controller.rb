# app/controllers/api/token/tokens_controller.rb
module Api
  module Token
    class TokensController < ApplicationController
      include Api::Concerns::JwtAuthenticable

      def usage
        # Get date range parameters (default to last 30 days)
        start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago.to_date
        end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

        # Get token usage logs for the user
        usage_logs = TokenUsageLog.where(user_id: @current_user.id)
                                  .where(created_at: start_date.beginning_of_day..end_date.end_of_day)

        # Aggregate data by day and usage type
        daily_usage = aggregate_daily_usage(usage_logs, start_date, end_date)

        # Calculate total stats
        total_stats = {
          total_queries: usage_logs.count,
          total_points_used: usage_logs.sum(:points_used),
          average_cost_per_query: usage_logs.average(:points_used).to_f.round(2),
          usage_by_type: usage_logs.group(:usage_type).sum(:points_used)
        }

        # Get current token settings
        token_settings = {
          token_usage_level: @current_user.token_usage_level,
          current_token: @current_user.user_token&.access_token&.truncate(10, omission: "...")
        }

        render_success({
          token_settings: token_settings,
          total_stats: total_stats,
          daily_usage: daily_usage
        })
      end

      def update_settings
        # Get the requested token usage level
        new_level = params[:token_usage_level]

        # Validate it's a valid level
        unless User.token_usage_levels.keys.include?(new_level)
          return render_error("Invalid token usage level", :unprocessable_entity)
        end

        # Update the user's token usage level
        if @current_user.update(token_usage_level: new_level)
          render_success({
            message: "Token usage level updated successfully",
            token_usage_level: @current_user.token_usage_level
          })
        else
          render_error("Failed", :unprocessable_entity, { errors: @current_user.errors.full_messages })
        end
      end

      private

      def aggregate_daily_usage(logs, start_date, end_date)
        daily_usage = {}

        # Initialize the result hash with all dates in range
        (start_date..end_date).each do |date|
          daily_usage[date.to_s] = {
            date: date.to_s,
            total_queries: 0,
            total_points: 0,
            by_type: {}
          }

          # Initialize counts for each usage type
          User.token_usage_levels.keys.each do |level|
            daily_usage[date.to_s][:by_type][level] = 0
          end
        end

        # Fill in actual data
        logs.each do |log|
          date = log.created_at.to_date.to_s
          usage_type = User.token_usage_levels.key(log.usage_type)

          daily_usage[date][:total_queries] += 1
          daily_usage[date][:total_points] += log.points_used
          daily_usage[date][:by_type][usage_type] += log.points_used
        end

        # Convert to array for easier consumption by clients
        daily_usage.values
      end
    end
  end
end
