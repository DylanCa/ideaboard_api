class Label < ApplicationRecord
  # Associations
  has_many :issue_labels, dependent: :destroy
  has_many :issues, through: :issue_labels
  has_many :pull_request_labels, dependent: :destroy
  has_many :pull_requests, through: :pull_request_labels
  belongs_to :github_repository

  # Validations
  validates :name, presence: true
  validates :is_bug, inclusion: { in: [ true, false ] }

  # Scopes
  scope :bugs, -> { where(is_bug: true) }
  scope :by_color, ->(color) { where(color: color) }
end
