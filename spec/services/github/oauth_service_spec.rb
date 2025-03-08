require 'rails_helper'

RSpec.describe Github::OauthService do
  describe '.authenticate' do
    let(:code) { 'test-auth-code' }

    before do
      # Set up Octokit authentication mocks (no change here)
      allow(described_class).to receive(:get_tokens).with(code).and_return({ access_token: 'test-access-token' })

      client_double = instance_double(Octokit::Client)
      allow(Octokit::Client).to receive(:new).with(access_token: 'test-access-token').and_return(client_double)
      allow(client_double).to receive(:user_authenticated?).and_return(true)

      # Use fixture data instead of directly creating mock data
      github_user_data = JSON.parse(File.read(Rails.root.join('spec/fixtures/github_api/user_data.json')))
      github_user = OpenStruct.new(
        id: github_user_data['viewer']['databaseId'],
        login: github_user_data['viewer']['login'],
        email: github_user_data['viewer']['email'],
        avatar_url: github_user_data['viewer']['avatarUrl']
      )

      allow(client_double).to receive(:user).and_return(github_user)

      # Background jobs
      allow(UserRepositoriesFetcherWorker).to receive(:perform_async)
      allow(UserContributionsFetcherWorker).to receive(:perform_async)
      allow(LoggerExtension).to receive(:log)
    end

    context 'when user does not exist' do
      let(:client_double) { instance_double(Octokit::Client) }
      let(:github_user) { double('GithubUser', id: 12345, login: 'test-user', email: 'test@example.com', avatar_url: 'https://github.com/avatar.png') }

      before do
        allow(Octokit::Client).to receive(:new).with(access_token: 'test-access-token').and_return(client_double)
        allow(client_double).to receive(:user_authenticated?).and_return(true)
        allow(client_double).to receive(:user).and_return(github_user)


        allow(described_class).to receive(:update_user_token).and_call_original
      end

      it 'creates a new user and returns authentication success' do
        allow(described_class).to receive(:create_new_user).and_call_original

        expect(ActiveRecord::Base).to receive(:transaction).and_call_original

        result = described_class.authenticate(code)

        expect(result[:is_authenticated]).to be true
        expect(result[:user]).to be_a(User)

        expect(result[:user].email).to eq('test@example.com')

        expect(result[:user].github_account).to be_present
        expect(result[:user].github_account.github_id).to eq(12345)
        expect(result[:user].github_account.github_username).to eq('test-user')

        expect(result[:user].user_stat).to be_present

        expect(UserRepositoriesFetcherWorker).to have_received(:perform_async)
        expect(UserContributionsFetcherWorker).to have_received(:perform_async)

        expect(LoggerExtension).to have_received(:log).with(
          :info,
          "User Authentication",
          hash_including(action: "new_user")
        )
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
        allow(described_class).to receive(:get_tokens).with(code).and_return({ access_token: 'test-access-token' })

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
