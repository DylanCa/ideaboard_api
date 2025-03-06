require 'rails_helper'

RSpec.describe UserStat, type: :model do
  subject { create(:user_stat) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:user_id) }
    it { should validate_uniqueness_of(:user_id) }
    it { should validate_presence_of(:reputation_points) }
    it { should validate_numericality_of(:reputation_points).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:high_rep_user) { create(:user_stat, reputation_points: 1000) }
    let!(:medium_rep_user) { create(:user_stat, reputation_points: 500) }
    let!(:low_rep_user) { create(:user_stat, reputation_points: 100) }
    let!(:zero_rep_user) { create(:user_stat, reputation_points: 0) }

    describe '.top_contributors' do
      it 'returns users ordered by reputation points in descending order' do
        top_contributors = UserStat.top_contributors

        expect(top_contributors.first).to eq(high_rep_user)
        expect(top_contributors.second).to eq(medium_rep_user)
        expect(top_contributors.third).to eq(low_rep_user)
        expect(top_contributors.last).to eq(zero_rep_user)
      end
    end

    describe '.active_contributors' do
      it 'returns users with positive reputation points' do
        active_contributors = UserStat.active_contributors

        expect(active_contributors).to include(high_rep_user)
        expect(active_contributors).to include(medium_rep_user)
        expect(active_contributors).to include(low_rep_user)
        expect(active_contributors).not_to include(zero_rep_user)
      end
    end
  end
end
