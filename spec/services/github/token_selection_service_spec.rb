require 'rails_helper'

RSpec.describe Github::TokenSelectionService do
  describe '.select_token' do
    let(:repo) { create(:github_repository, author_username: 'test-author') }

    context 'when username is provided' do
      let(:username) { 'test-author' }
      let(:user) { create(:user, :with_github_account, :with_access_token) }

      before do
        allow(user.github_account).to receive(:github_username).and_return(username)
      end

      it 'returns token from the user with matching username' do
        allow(User).to receive_message_chain(:joins, :where, :first).and_return(user)

        result = described_class.select_token(nil, username)

        expect(result[0]).to eq(user.id)
        expect(result[1]).to eq(user.access_token)
        expect(result[2]).to eq(:personal)
      end
    end

    context 'when only repository is provided' do
      it 'selects appropriate token based on repository' do
        allow(described_class).to receive(:select_token_for_repository).with(repo).and_return([ 1, 'token', :contributed ])

        result = described_class.select_token(repo, nil)

        expect(result).to eq([ 1, 'token', :contributed ])
      end
    end
  end

  describe '.select_token_for_repository' do
    let(:repo) { create(:github_repository) }

    context 'when cache exists' do
      before do
        allow(Rails.cache).to receive(:read).with("token_for_repo_#{repo.id}").and_return([ 1, 'cached_token', :personal ])
      end

      it 'returns cached token' do
        result = described_class.select_token_for_repository(repo)

        expect(result).to eq([ 1, 'cached_token', :personal ])
        expect(Rails.cache).to have_received(:read).with("token_for_repo_#{repo.id}")
      end
    end

    context 'when cache does not exist' do
      before do
        allow(Rails.cache).to receive(:read).and_return(nil)
        allow(Rails.cache).to receive(:write)
        allow(described_class).to receive(:detect_appropriate_token).and_return([ 2, 'new_token', :contributed ])
      end

      it 'detects appropriate token and caches it' do
        result = described_class.select_token_for_repository(repo)

        expect(result).to eq([ 2, 'new_token', :contributed ])
        expect(described_class).to have_received(:detect_appropriate_token).with(repo)
        expect(Rails.cache).to have_received(:write).with("token_for_repo_#{repo.id}", [ 2, 'new_token', :contributed ], expires_in: 5.minutes)
      end
    end

    context 'with cache miss requiring database queries' do
      before do
        allow(Rails.cache).to receive(:read).and_return(nil)
        allow(Rails.cache).to receive(:write)

        owner = create(:user, :with_github_account, :with_access_token)
        owner.github_account.update(github_username: repo.author_username)

        contributor = create(:user, :with_access_token, token_usage_level: :contributed)
        create(:user_repository_stat, user: contributor, github_repository: repo)

        global_user = create(:user, :with_access_token, token_usage_level: :global_pool)
      end

      it 'detects appropriate token and caches it' do
        result = described_class.select_token_for_repository(repo)

        expect(result[2]).to eq(:personal)
        expect(Rails.cache).to have_received(:write)
      end
    end
  end
end
