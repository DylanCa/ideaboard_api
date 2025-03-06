require 'rails_helper'

RSpec.describe UserToken, type: :model do
  subject { create(:user_token) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:access_token) }
  end

  describe 'scopes' do
    describe '.recent' do
      let!(:older_token) { create(:user_token, created_at: 2.days.ago) }
      let!(:newer_token) { create(:user_token, created_at: 1.day.ago) }

      it 'returns tokens ordered by creation time in descending order' do
        expect(UserToken.recent.first).to eq(newer_token)
        expect(UserToken.recent.last).to eq(older_token)
      end
    end
  end
end
