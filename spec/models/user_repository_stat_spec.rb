require 'rails_helper'

RSpec.describe UserRepositoryStat, type: :model do
  subject { create(:user_repository_stat) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:github_repository) }
  end

  describe 'validations' do
    subject { create(:user_repository_stat) }

    it { should validate_uniqueness_of(:user_id).scoped_to(:github_repository_id) }

    it { should validate_presence_of(:opened_prs_count) }
    it { should validate_presence_of(:merged_prs_count) }
    it { should validate_presence_of(:issues_opened_count) }
    it { should validate_presence_of(:issues_closed_count) }
    it { should validate_presence_of(:issues_with_pr_count) }

    it { should validate_numericality_of(:opened_prs_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:merged_prs_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:issues_opened_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:issues_closed_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:issues_with_pr_count).is_greater_than_or_equal_to(0) }
  end
end
