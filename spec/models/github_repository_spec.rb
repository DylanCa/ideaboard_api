require 'rails_helper'

RSpec.describe GithubRepository, type: :model do
  subject { create(:github_repository) }

  describe 'associations' do
    it { should have_many(:github_repository_topics).dependent(:destroy) }
    it { should have_many(:topics).through(:github_repository_topics) }
    it { should have_many(:issues).dependent(:destroy) }
    it { should have_many(:pull_requests).dependent(:destroy) }
    it { should have_many(:user_repository_stats).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:full_name) }
    it { should validate_uniqueness_of(:full_name) }
    it { should validate_presence_of(:github_id) }
    it { should validate_uniqueness_of(:github_id) }
    it { should validate_presence_of(:stars_count) }
    it { should validate_presence_of(:forks_count) }
    it { should validate_presence_of(:github_created_at) }
    it { should validate_presence_of(:github_updated_at) }
    it { should validate_numericality_of(:stars_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:forks_count).is_greater_than_or_equal_to(0) }

    it { should validate_inclusion_of(:is_fork).in_array([ true, false ]) }
    it { should validate_inclusion_of(:archived).in_array([ true, false ]) }
    it { should validate_inclusion_of(:disabled).in_array([ true, false ]) }
    it { should validate_inclusion_of(:visible).in_array([ true, false ]) }
    it { should validate_inclusion_of(:has_contributing).in_array([ true, false ]) }
    it { should validate_inclusion_of(:app_installed).in_array([ true, false ]) }
    it { should validate_inclusion_of(:webhook_installed).in_array([ true, false ]) }
  end

  describe 'enums' do
    it { should define_enum_for(:update_method).with_values(polling: 0, webhook: 1) }
  end

  describe 'scopes' do
    let!(:visible_repo) { create(:github_repository, visible: true, archived: false, disabled: false) }
    let!(:invisible_repo) { create(:github_repository, visible: false) }
    let!(:archived_repo) { create(:github_repository, archived: true) }
    let!(:disabled_repo) { create(:github_repository, disabled: true) }
    let!(:ruby_repo) { create(:github_repository, language: 'ruby') }
    let!(:javascript_repo) { create(:github_repository, language: 'javascript') }
    let!(:high_stars_repo) { create(:github_repository, stars_count: 1000) }
    let!(:low_stars_repo) { create(:github_repository, stars_count: 10) }

    describe '.visible' do
      it 'returns only visible, non-archived, non-disabled repositories' do
        expect(GithubRepository.visible).to include(visible_repo)
        expect(GithubRepository.visible).not_to include(invisible_repo)
        expect(GithubRepository.visible).not_to include(archived_repo)
        expect(GithubRepository.visible).not_to include(disabled_repo)
      end
    end

    describe '.by_stars' do
      it 'returns repositories ordered by stars count in descending order' do
        expect(GithubRepository.by_stars.first).to eq(high_stars_repo)
        expect(GithubRepository.by_stars.last).not_to eq(high_stars_repo)
      end
    end

    describe '.active' do
      it 'returns non-archived, non-disabled repositories' do
        expect(GithubRepository.active).to include(visible_repo)
        expect(GithubRepository.active).to include(invisible_repo)
        expect(GithubRepository.active).not_to include(archived_repo)
        expect(GithubRepository.active).not_to include(disabled_repo)
      end
    end

    describe '.with_language' do
      it 'returns repositories with the specified language' do
        expect(GithubRepository.with_language('ruby')).to include(ruby_repo)
        expect(GithubRepository.with_language('ruby')).not_to include(javascript_repo)
      end
    end

    describe '.recently_updated' do
      let!(:recently_updated) { create(:github_repository, github_updated_at: 1.hour.ago) }
      let!(:older_update) { create(:github_repository, github_updated_at: 1.week.ago) }

      it 'returns repositories ordered by update time in descending order' do
        expect(GithubRepository.recently_updated.first).to eq(recently_updated)
        expect(GithubRepository.recently_updated.last).not_to eq(recently_updated)
      end
    end
  end

  describe '#last_polled_at_date' do
    let(:repository) { create(:github_repository) }

    context 'when last_polled_at is present' do
      let(:poll_time) { Time.parse('2025-01-01T12:00:00Z') }

      before do
        repository.update(last_polled_at: poll_time)
      end

      it 'returns the formatted date' do
        expect(repository.last_polled_at_date).to eq('2025-01-01T12:00:00+00:00')
      end
    end

    context 'when last_polled_at is nil' do
      before do
        repository.update(last_polled_at: nil)
      end

      it 'returns nil' do
        expect(repository.last_polled_at_date).to be_nil
      end
    end
  end
end
