class Label < ApplicationRecord
  # Associations
  has_many :issue_labels, dependent: :destroy
  has_many :issues, through: :issue_labels
  has_many :pull_request_labels, dependent: :destroy
  has_many :pull_requests, through: :pull_request_labels

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :is_bug, inclusion: { in: [ true, false ] }

  # Scopes
  scope :bugs, -> { where(is_bug: true) }
  scope :by_color, ->(color) { where(color: color) }
  scope :popular, -> {
    left_joins(:issue_labels, :pull_request_labels)
      .group(:id)
      .order("COUNT(issue_labels.id) + COUNT(pull_request_labels.id) DESC")
  }
end
