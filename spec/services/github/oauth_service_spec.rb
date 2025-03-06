require 'rails_helper'

RSpec.describe Github::OauthService do
  describe '.authenticate' do
    let(:code) { 'test-auth-code' }
    let(:github_user) do
      instance_double(
        Sawyer::Resource,
        id: 12345,
        login: 'test-user',
        email: 'test@example.com',
        avatar_url: 'https://github.com/avatar.png'
      )
    end

    before do
      # Mock token exchange
      allow(described_class).to receive(:get_tokens).with(code).and_return({ access_token: 'test-access-token' })

      # Mock Octokit client
      client_double = instance_double(Octokit::Client)
      allow(Octokit::Client).to receive(:new).with(access_token: 'test-access-token').and_return(client_double)
      allow(client_double).to receive(:user_authenticated?).and_return(true)
      allow(client_double).to receive(:user).and_return(github_user)

      # Mock worker enqueuing
      allow(UserRepositoriesFetcherWorker).to receive(:perform_async)
      allow(UserContributionsFetcherWorker).to receive(:perform_async)

      # Mock logger
      allow(LoggerExtension).to receive(:log)
    end

    context 'when user does not exist' do
      before do
        allow(User).to receive_message_chain(:with_github_id, :first).and_return(nil)
        allow(described_class).to receive(:create_new_user).with(an_instance_of(Octokit::Client)).and_return(
          create(:user)
        )
        allow(described_class).to receive(:update_user_token)
      end

      it 'creates a new user and returns authentication success' do
        result = described_class.authenticate(code)

        expect(result[:is_authenticated]).to be true
        expect(result).to have_key(:user)
        expect(described_class).to have_received(:create_new_user)
        expect(described_class).to have_received(:update_user_token)
        expect(UserRepositoriesFetcherWorker).to have_received(:perform_async)
        expect(UserContributionsFetcherWorker).to have_received(:perform_async)
        expect(LoggerExtension).to have_received(:log).with(:info, "User Authentication", hash_including(action: "new_user"))
      end
    end

    context 'when user exists' do
      let(:existing_user) { create(:user) }

      before do
        allow(User).to receive_message_chain(:with_github_id, :first).and_return(existing_user)
        allow(described_class).to receive(:update_user_token)
      end

      it 'updates the user token and returns authentication success' do
        result = described_class.authenticate(code)

        expect(result[:is_authenticated]).to be true
        expect(result[:user]).to eq(existing_user)
        expect(described_class).to have_received(:update_user_token)
        expect(UserRepositoriesFetcherWorker).not_to have_received(:perform_async).with(existing_user.id)
        expect(UserContributionsFetcherWorker).to have_received(:perform_async).with(existing_user.id)
        expect(LoggerExtension).to have_received(:log).with(:info, "User Authentication", hash_including(action: "existing_user"))
      end
    end

    context 'when authentication fails' do
      before do
        client_double = instance_double(Octokit::Client)
        allow(Octokit::Client).to receive(:new).with(access_token: 'test-access-token').and_return(client_double)
        allow(client_double).to receive(:user_authenticated?).and_return(false)
      end

      it 'returns authentication failure' do
        result = described_class.authenticate(code)

        expect(result[:is_authenticated]).to be false
        expect(UserRepositoriesFetcherWorker).not_to have_received(:perform_async)
        expect(UserContributionsFetcherWorker).not_to have_received(:perform_async)
      end
    end
  end
end
