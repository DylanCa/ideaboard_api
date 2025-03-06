require 'rails_helper'

RSpec.describe GithubAccount, type: :model do
  subject { create(:github_account) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:github_id) }
    it { should validate_uniqueness_of(:github_id) }
    it { should validate_presence_of(:github_username) }
    it { should validate_uniqueness_of(:github_username) }
    it { should validate_presence_of(:user_id) }
    it { should validate_uniqueness_of(:user_id) }
  end

  describe '#last_polled_at_date' do
    let(:account) { create(:github_account) }

    context 'when last_polled_at is present' do
      let(:poll_time) { Time.parse('2025-01-01T12:00:00Z') }

      before do
        account.update(last_polled_at: poll_time)
      end

      it 'returns the formatted date' do
        expect(account.last_polled_at_date).to eq('2025-01-01T12:00:00+00:00')
      end
    end

    context 'when last_polled_at is nil' do
      before do
        account.update(last_polled_at: nil)
      end

      it 'returns nil' do
        expect(account.last_polled_at_date).to be_nil
      end
    end
  end
end
