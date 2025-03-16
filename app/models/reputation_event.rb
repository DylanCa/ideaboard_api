class ReputationEvent < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :github_repository, optional: true
  belongs_to :pull_request, optional: true
  belongs_to :issue, optional: true

  # Validations
  validates :points_change, presence: true
  validates :points_breakdown, presence: true
  validates :event_type, presence: true
  validates :occurred_at, presence: true

  # Scopes
  scope :recent, -> { order(occurred_at: :desc) }
  scope :positive, -> { where("points_change > 0") }
  scope :negative, -> { where("points_change < 0") }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :in_date_range, ->(start_date, end_date) { where(occurred_at: start_date.beginning_of_day..end_date.end_of_day) }

  # Event types
  TYPES = {
    pr_merged: "PR_MERGED",
    pr_closed: "PR_CLOSED",
    issue_opened: "ISSUE_OPENED",
    issue_closed: "ISSUE_CLOSED",
    contribution_streak: "CONTRIBUTION_STREAK",
    new_repository_contribution: "NEW_REPOSITORY_CONTRIBUTION"
  }

  # Generate human-readable description from the points breakdown
  def generate_description
    case event_type
    when TYPES[:pr_merged]
      repo_name = github_repository&.full_name || "unknown repository"
      pr_number = pull_request&.number || "unknown"

      parts = []
      breakdown = points_breakdown.symbolize_keys

      # Add base points description
      if breakdown[:base_points].present?
        parts << "#{breakdown[:base_points]} base points for merged PR"
      end

      # Add repo factor description
      if breakdown[:repo_factor].present? && breakdown[:repo_factor] != 1.0
        stars = github_repository&.stars_count || 0
        parts << "#{((breakdown[:repo_factor] - 1) * 100).round}% bonus for #{stars} stars"
      end

      # Add issue relationship description
      if breakdown[:issue_bonus].present? && breakdown[:issue_bonus] > 0
        parts << "#{breakdown[:issue_bonus]} points for closing #{breakdown[:related_issues]} issue(s)"
      end

      # Add diversity bonus
      if breakdown[:diversity_bonus].present? && breakdown[:diversity_bonus] > 0
        parts << "#{breakdown[:diversity_bonus]}% diversity bonus (#{breakdown[:repo_count]} repos)"
      end

      # Add streak bonus
      if breakdown[:streak_bonus_percentage].present? && breakdown[:streak_bonus_percentage] > 0
        parts << "#{breakdown[:streak_bonus_percentage]}% streak bonus (+#{breakdown[:streak_bonus_points]} points)"
      end

      "Merged PR ##{pr_number} in #{repo_name}: +#{points_change} points (#{parts.join(', ')})"

    when TYPES[:pr_closed]
      repo_name = github_repository&.full_name || "unknown repository"
      pr_number = pull_request&.number || "unknown"
      "Closed PR ##{pr_number} in #{repo_name} without merging: #{points_change} points"

    when TYPES[:issue_opened]
      repo_name = github_repository&.full_name || "unknown repository"
      issue_number = issue&.number || "unknown"

      parts = []
      breakdown = points_breakdown.symbolize_keys

      # Add base points description
      if breakdown[:base_points].present?
        parts << "#{breakdown[:base_points]} base points for new issue"
      end

      # Add repo factor description
      if breakdown[:repo_factor].present? && breakdown[:repo_factor] != 1.0
        stars = github_repository&.stars_count || 0
        parts << "#{((breakdown[:repo_factor] - 1) * 100).round}% bonus for #{stars} stars"
      end

      # Add streak bonus
      if breakdown[:streak_bonus_percentage].present? && breakdown[:streak_bonus_percentage] > 0
        parts << "#{breakdown[:streak_bonus_percentage]}% streak bonus (+#{breakdown[:streak_bonus_points]} points)"
      end

      "Opened Issue ##{issue_number} in #{repo_name}: +#{points_change} points (#{parts.join(', ')})"

    when TYPES[:issue_closed]
      repo_name = github_repository&.full_name || "unknown repository"
      issue_number = issue&.number || "unknown"

      parts = []
      breakdown = points_breakdown.symbolize_keys

      # Add base points description
      if breakdown[:base_points].present?
        parts << "#{breakdown[:base_points]} base points for closing issue"
      end

      # Add PR bonus description
      if breakdown[:closed_by_pr].present? && breakdown[:closed_by_pr] && breakdown[:pr_bonus].present?
        parts << "#{breakdown[:pr_bonus]} bonus points for closing with PR"
      end

      # Add repo factor description
      if breakdown[:repo_factor].present? && breakdown[:repo_factor] != 1.0
        stars = github_repository&.stars_count || 0
        parts << "#{((breakdown[:repo_factor] - 1) * 100).round}% bonus for #{stars} stars"
      end

      # Add streak bonus
      if breakdown[:streak_bonus_percentage].present? && breakdown[:streak_bonus_percentage] > 0
        parts << "#{breakdown[:streak_bonus_percentage]}% streak bonus (+#{breakdown[:streak_bonus_points]} points)"
      end

      "Closed Issue ##{issue_number} in #{repo_name}: +#{points_change} points (#{parts.join(', ')})"
    when TYPES[:new_repository_contribution]
      repo_name = github_repository&.full_name || "unknown repository"

      parts = []
      breakdown = points_breakdown.symbolize_keys

      # Add base points description
      if breakdown[:base_points].present?
        parts << "#{breakdown[:base_points]} points for first contribution"
      end

      "First contribution to #{repo_name}: +#{points_change} points (#{parts.join(', ')})"
    else
      # Generic description
      "Reputation change: #{points_change} points"
    end
  end

  # Return the description (generate if not already set)
  def description
    self[:description] || generate_description
  end
end
