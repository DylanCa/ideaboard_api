# app/controllers/api/analytics_controller.rb
module Api
  class AnalyticsController < ApplicationController
    include Api::Concerns::JwtAuthenticable

    def user
      # Overall user analytics
      user_stats = @current_user.user_stat
      repository_stats = UserRepositoryStat.where(user_id: @current_user.id)

      # Calculate aggregated metrics
      total_prs = repository_stats.sum(:opened_prs_count)
      merged_prs = repository_stats.sum(:merged_prs_count)
      closed_prs = repository_stats.sum(:closed_prs_count)
      total_issues = repository_stats.sum(:issues_opened_count)
      closed_issues = repository_stats.sum(:issues_closed_count)

      # Calculate PR success rate (merged PRs / opened PRs)
      pr_success_rate = total_prs > 0 ? ((merged_prs.to_f / total_prs) * 100).round(2) : 0

      # Calculate issue closure rate
      issue_closure_rate = total_issues > 0 ? ((closed_issues.to_f / total_issues) * 100).round(2) : 0

      # Get active repositories (where user has contributions)
      active_repositories_count = repository_stats.count

      # Get current streak
      current_streak = repository_stats.maximum(:contribution_streak) || 0

      render_success({
        user_id: @current_user.id,
        username: @current_user.github_account&.github_username,
        reputation_points: user_stats&.reputation_points || 0,
        contribution_stats: {
          total_prs: total_prs,
          merged_prs: merged_prs,
          closed_prs: closed_prs,
          pr_success_rate: pr_success_rate,
          total_issues: total_issues,
          closed_issues: closed_issues,
          issue_closure_rate: issue_closure_rate
        },
        repository_stats: {
          active_repositories: active_repositories_count,
          current_streak: current_streak
        },
        time_analytics: {
          first_contribution: repository_stats.minimum(:first_contribution_at),
          most_recent_contribution: repository_stats.maximum(:last_contribution_at)
        }
      })
    end

    def repositories
      # Get overall repository analytics
      repositories = GithubRepository.visible.includes(:issues, :pull_requests)

      # Calculate repository metrics
      repo_count = repositories.count
      active_repos = repositories.where("github_updated_at > ?", 3.months.ago).count

      # Calculate average metrics
      avg_stars = repositories.average(:stars_count)
      avg_forks = repositories.average(:forks_count)

      # Get language distribution
      languages = repositories.group(:language).count
                              .sort_by { |_, count| -count }
                              .first(10)
                              .to_h

      # Get top repositories by stars
      top_repos = repositories.order(stars_count: :desc).limit(5).map do |repo|
        {
          id: repo.id,
          full_name: repo.full_name,
          stars: repo.stars_count,
          forks: repo.forks_count
        }
      end

      render_success({
                       repository_counts: {
                         total: repo_count,
                         active: active_repos,
                         inactive: repo_count - active_repos
                       },
                       average_metrics: {
                         stars: avg_stars.to_f.round(2),
                         forks: avg_forks.to_f.round(2)
                       },
                       language_distribution: languages,
                       top_repositories: top_repos
                     })
    end

    def repository
      repository = GithubRepository.find(params[:id])

      # Get pull request statistics
      prs = repository.pull_requests
      open_prs = prs.where(closed_at: nil).count
      merged_prs = prs.where.not(merged_at: nil).count
      closed_prs = prs.where.not(closed_at: nil).where(merged_at: nil).count

      # Get issue statistics
      issues = repository.issues
      open_issues = issues.where(closed_at: nil).count
      closed_issues = issues.where.not(closed_at: nil).count

      # Get top contributors
      top_contributors = UserRepositoryStat.where(github_repository_id: repository.id)
                                           .order(opened_prs_count: :desc)
                                           .limit(5)
                                           .includes(:user)
                                           .map do |stat|
        username = stat.user.github_account&.github_username || "Unknown User"
        {
          user_id: stat.user_id,
          username: username,
          contributions: stat.opened_prs_count,
          merged_prs: stat.merged_prs_count
        }
      end

      # Calculate activity trends (PRs and issues per month for last 6 months)
      months = 6
      activity_data = []

      months.times do |i|
        month_start = (months - i).months.ago.beginning_of_month
        month_end = (months - i - 1).months.ago.beginning_of_month

        month_prs = prs.where(github_created_at: month_start..month_end).count
        month_issues = issues.where(github_created_at: month_start..month_end).count

        activity_data << {
          month: month_start.strftime("%b %Y"),
          prs: month_prs,
          issues: month_issues
        }
      end

      render_success({
        repository: {
          id: repository.id,
          full_name: repository.full_name,
          description: repository.description,
          stars: repository.stars_count,
          forks: repository.forks_count,
          language: repository.language,
          created_at: repository.github_created_at,
          updated_at: repository.github_updated_at
        },
        pull_request_stats: {
          total: prs.count,
          open: open_prs,
          merged: merged_prs,
          closed: closed_prs
        },
        issue_stats: {
          total: issues.count,
          open: open_issues,
          closed: closed_issues
        },
        top_contributors: top_contributors,
        activity_trend: activity_data
      })
    end
  end
end
