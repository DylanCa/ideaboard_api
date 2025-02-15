class IssueLabel < ApplicationRecord
  # Associations
  belongs_to :issue
  belongs_to :label

  # Validations
  validates :issue_id, presence: true
  validates :label_id, presence: true
  validates :issue_id, uniqueness: { scope: :label_id }
end