class PullRequestLabel < ApplicationRecord
  # Associations
  belongs_to :pull_request
  belongs_to :label

  # Validations
  validates :pull_request_id, presence: true
  validates :label_id, presence: true
  validates :pull_request_id, uniqueness: { scope: :label_id }
end
