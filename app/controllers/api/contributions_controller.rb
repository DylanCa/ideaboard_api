module Api
  class ContributionsController < ApplicationController
    include Api::Concerns::JwtAuthenticable
    skip_before_action :authenticate_user!, only: [ :repository_contributions ]
    before_action :set_repository, only: [ :repository_contributions ]

    # GET /api/users/contributions
    def user_contributions
      # Get all contribution stats for the current user
      stats = @current_user.user_repository_stats.includes(:github_repository)
                           .order(merged_prs_count: :desc)
                           .page(params[:page] || 1)
                           .per(params[:per_page] || 20)

      # Calculate total contributions
      totals = {
        total_prs: stats.sum(:opened_prs_count),
        total_merged_prs: stats.sum(:merged_prs_count),
        total_issues: stats.sum(:issues_opened_count),
        total_closed_issues: stats.sum(:issues_closed_count),
        total_repositories: stats.count
      }

      render_success(
        {
          contributions: stats,
          totals: totals
        },
        {
          total_count: stats.total_count,
          current_page: stats.current_page,
          total_pages: stats.total_pages
        }
      )
    end

    # GET /api/users/contributions/history
    def user_history
      # Get date range parameters (default to last 6 months)
      start_date = params[:start_date] ? Date.parse(params[:start_date]) : 6.months.ago.to_date
      end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today

      # Get all PRs and issues for the user
      prs = PullRequest.where(author_username: @current_user.github_username)
                       .where(github_created_at: start_date.beginning_of_day..end_date.end_of_day)
                       .order(:github_created_at)

      issues = Issue.where(author_username: @current_user.github_username)
                    .where(github_created_at: start_date.beginning_of_day..end_date.end_of_day)
                    .order(:github_created_at)

      # Aggregate data by month
      monthly_data = aggregate_monthly_contributions(prs, issues, start_date, end_date)

      render_success(
        {
          history: monthly_data
        },
        {
          start_date: start_date,
          end_date: end_date,
          total_prs: prs.count,
          total_issues: issues.count
        }
      )
    end

    # GET /api/users/streaks
    def user_streaks
      # Find all stats for the user
      stats = @current_user.user_repository_stats

      # Calculate current streak
      current_streak = stats.maximum(:contribution_streak) || 0

      # Calculate longest streak
      longest_streak = current_streak

      # Calculate contribution calendar data (for GitHub-style heat map)
      calendar_data = calculate_contribution_calendar(@current_user)

      render json: {
        current_streak: current_streak,
        longest_streak: longest_streak,
        calendar_data: calendar_data
      }
    end

    # GET /api/repositories/:id/contributions
    def repository_contributions
      # Get all contribution stats for this repository
      stats = UserRepositoryStat.where(github_repository_id: @repository.id)
                                .includes(:user)
                                .order(merged_prs_count: :desc)
                                .page(params[:page] || 1)
                                .per(params[:per_page] || 20)

      # Calculate repository totals
      totals = {
        total_contributors: stats.count,
        total_prs: stats.sum(:opened_prs_count),
        total_merged_prs: stats.sum(:merged_prs_count),
        total_issues: stats.sum(:issues_opened_count)
      }

      render_success(
        {
          contributions: stats,
          totals: totals
        },
        {
          repository: @repository.full_name,
          stars: @repository.stars_count,
          forks: @repository.forks_count,
          total_count: stats.total_count,
          current_page: stats.current_page,
          total_pages: stats.total_pages
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

    def aggregate_monthly_contributions(prs, issues, start_date, end_date)
      result = {}

      # Initialize each month with zeroes
      current_date = start_date.beginning_of_month
      while current_date <= end_date
        month_key = current_date.strftime("%Y-%m")
        result[month_key] = {
          year: current_date.year,
          month: current_date.month,
          month_name: current_date.strftime("%B"),
          opened_prs: 0,
          merged_prs: 0,
          closed_prs: 0,
          opened_issues: 0,
          closed_issues: 0,
          total_contributions: 0
        }
        current_date = current_date.next_month
      end

      # Count PRs by month
      prs.each do |pr|
        month_key = pr.github_created_at.strftime("%Y-%m")
        next unless result[month_key]

        result[month_key][:opened_prs] += 1
        result[month_key][:total_contributions] += 1

        if pr.merged_at.present?
          merge_month_key = pr.merged_at.strftime("%Y-%m")
          if result[merge_month_key]
            result[merge_month_key][:merged_prs] += 1
            result[merge_month_key][:total_contributions] += 1
          end
        elsif pr.closed_at.present?
          close_month_key = pr.closed_at.strftime("%Y-%m")
          if result[close_month_key]
            result[close_month_key][:closed_prs] += 1
            result[close_month_key][:total_contributions] += 1
          end
        end
      end

      # Count issues by month
      issues.each do |issue|
        month_key = issue.github_created_at.strftime("%Y-%m")
        next unless result[month_key]

        result[month_key][:opened_issues] += 1
        result[month_key][:total_contributions] += 1

        if issue.closed_at.present?
          close_month_key = issue.closed_at.strftime("%Y-%m")
          if result[close_month_key]
            result[close_month_key][:closed_issues] += 1
            result[close_month_key][:total_contributions] += 1
          end
        end
      end

      # Convert to array for easier client-side consumption
      result.values
    end

    def calculate_contribution_calendar(user)
      # Get contributions for the past year
      end_date = Date.today
      start_date = end_date - 1.year

      # Get all PRs and issues created by the user in this period
      prs = PullRequest.where(author_username: user.github_username)
                       .where("github_created_at >= ?", start_date)

      issues = Issue.where(author_username: user.github_username)
                    .where("github_created_at >= ?", start_date)

      # Initialize calendar data
      calendar_data = {}

      # Process PRs
      process_contributions_for_calendar(calendar_data, prs, :github_created_at)
      process_contributions_for_calendar(calendar_data, prs.where.not(merged_at: nil), :merged_at)

      # Process issues
      process_contributions_for_calendar(calendar_data, issues, :github_created_at)
      process_contributions_for_calendar(calendar_data, issues.where.not(closed_at: nil), :closed_at)

      # Convert to array format for client
      calendar_data.map do |date, count|
        { date: date, count: count }
      end.sort_by { |item| item[:date] }
    end

    def process_contributions_for_calendar(calendar_data, items, date_field)
      items.each do |item|
        date = item.send(date_field).to_date.to_s
        calendar_data[date] ||= 0
        calendar_data[date] += 1
      end
    end
  end
end
