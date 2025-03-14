# spec/services/github/webhook_service_spec.rb
require 'rails_helper'

RSpec.describe Github::WebhookService do
  let(:repository) { create(:github_repository, full_name: "owner/repo") }
  let(:user) { create(:user, :with_github_account, :with_access_token) }
  let(:webhook_secret) { "fake_webhook_secret" }
  let(:callback_url) { "https://example.com/api/webhook" }

  describe '.create_webhook' do
    before do
      allow(Rails.application.routes.url_helpers).to receive(:api_webhook_events_url).and_return(callback_url)

      @client = instance_double(Octokit::Client)
      allow(Octokit::Client).to receive(:new).with(access_token: user.access_token).and_return(@client)
      allow(@client).to receive(:permission_level)
                          .with(repository.full_name, user.github_account.github_username)
                          .and_return({ permission: "admin" })
    end

    context 'when webhook creation is successful' do
      let(:webhook) { OpenStruct.new(id: "webhook123") }

      before do
        allow(@client).to receive(:create_hook).and_return(webhook)
      end

      it 'returns success and the webhook object' do
        result = described_class.create_webhook(repository, user, webhook_secret, callback_url: callback_url)

        expect(result[:success]).to be true
        expect(result[:webhook]).to eq(webhook)

        expect(@client).to have_received(:create_hook).with(
          repository.full_name,
          'web',
          {
            url: callback_url,
            content_type: 'json',
            secret: webhook_secret
          },
          { events: [ 'pull_request', 'issues', 'repository' ], active: true }
        )
      end
    end

    context 'when webhook creation fails' do
      before do
        allow(@client).to receive(:create_hook).and_raise(Octokit::Error.new)
        allow(LoggerExtension).to receive(:log)
      end

      it 'returns failure with error message' do
        result = described_class.create_webhook(repository, user, webhook_secret)

        expect(result[:success]).to be false
        expect(result[:message]).to be_present
        expect(LoggerExtension).to have_received(:log)
      end
    end
  end

  describe '.delete_webhook' do
    before do
      @client = instance_double(Octokit::Client)
      allow(Octokit::Client).to receive(:new).with(access_token: user.access_token).and_return(@client)
    end

    context 'when repository has a known webhook ID' do
      before do
        repository.update(github_webhook_id: "webhook123")
        allow(@client).to receive(:remove_hook)
      end

      it 'removes the webhook using the ID' do
        result = described_class.delete_webhook(repository, user.access_token)

        expect(result[:success]).to be true
        expect(@client).to have_received(:remove_hook).with(
          repository.full_name,
          repository.github_webhook_id
        )
      end
    end

    context 'when repository does not have a known webhook ID' do
      let(:hooks) do
        [
          OpenStruct.new(id: "webhook123", config: OpenStruct.new(url: callback_url)),
          OpenStruct.new(id: "webhook456", config: OpenStruct.new(url: "https://other.example.com"))
        ]
      end

      before do
        repository.update(github_webhook_id: nil)
        allow(Rails.application.routes.url_helpers).to receive(:api_webhook_events_url).and_return(callback_url)
        allow(@client).to receive(:hooks).and_return(hooks)
        allow(@client).to receive(:remove_hook)
      end

      it 'finds and removes the matching webhook' do
        result = described_class.delete_webhook(repository, user.access_token)

        expect(result[:success]).to be true
        expect(@client).to have_received(:remove_hook).with(
          repository.full_name,
          "webhook123"
        )
      end

      context 'when no matching webhook is found' do
        let(:hooks) do
          [
            OpenStruct.new(id: "webhook456", config: OpenStruct.new(url: "https://other.example.com"))
          ]
        end

        it 'returns not_found status' do
          result = described_class.delete_webhook(repository, user.access_token)

          expect(result[:not_found]).to be true
          expect(@client).not_to have_received(:remove_hook)
        end
      end
    end

    context 'when webhook deletion fails with NotFound' do
      before do
        repository.update(github_webhook_id: "webhook123")
        allow(@client).to receive(:remove_hook).and_raise(Octokit::NotFound)
      end

      it 'returns not_found status' do
        result = described_class.delete_webhook(repository, user.access_token)

        expect(result[:not_found]).to be true
      end
    end

    context 'when webhook deletion fails with other error' do
      before do
        repository.update(github_webhook_id: "webhook123")
        allow(@client).to receive(:remove_hook).and_raise(Octokit::Error.new)
        allow(LoggerExtension).to receive(:log)
      end

      it 'returns failure with error message' do
        result = described_class.delete_webhook(repository, user.access_token)

        expect(result[:success]).to be false
        expect(result[:message]).to be_present
        expect(LoggerExtension).to have_received(:log)
      end
    end
  end
end
