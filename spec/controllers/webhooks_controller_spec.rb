require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_access_token) }
  let(:repository) { create(:github_repository, author_username: user.github_account.github_username) }

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow_any_instance_of(JwtAuthenticable).to receive(:extract_token).and_return("test-token")
    allow(JwtService).to receive(:decode).and_return({ "user_id" => user.id, "github_username" => user.github_account.github_username })
    controller.instance_variable_set(:@current_user, user)
  end

  describe "POST #create" do
    let(:valid_params) { { repository_id: repository.id } }

    before do
      allow(Github::WebhookService).to receive(:create_webhook).with(
        repository,
        anything,
        anything,
        hash_including(:callback_url)  # Match any callback URL
      ).and_return({
                     success: true,
                     webhook: OpenStruct.new(id: "webhook123")
                   })
    end

    context "with valid parameters" do
      it "creates a webhook for the repository" do
        post :create, params: valid_params

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include(
                                               "message" => "Webhook successfully installed",
                                               "repository_id" => repository.id,
                                               "webhook_installed" => true
                                             )

        repository.reload
        expect(repository.webhook_installed).to be true
        expect(repository.webhook_secret).not_to be_nil
        expect(repository.github_webhook_id).to eq("webhook123")
      end
    end

    context "when the repository already has a webhook" do
      before do
        repository.update(webhook_installed: true, webhook_secret: "existing_secret")
      end

      it "returns a message that webhook is already installed" do
        post :create, params: valid_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
                                               "message" => "Webhook already installed",
                                               "repository_id" => repository.id,
                                               "webhook_installed" => true
                                             )

        # Should not call the webhook service
        expect(Github::WebhookService).not_to have_received(:create_webhook)
      end
    end

    context "when the repository is not found" do
      it "returns a not found error" do
        post :create, params: { repository_id: 9999 }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include("error" => "Repository not found")
      end
    end

    context "when the user does not have permission" do
      let(:other_repository) { create(:github_repository, author_username: "other_user") }

      it "returns an unauthorized error" do
        post :create, params: { repository_id: other_repository.id }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
                                               "error" => "Unauthorized to add webhooks to this repository"
                                             )
      end
    end

    context "when GitHub API returns an error" do
      before do
        allow(Github::WebhookService).to receive(:create_webhook).and_return({
                                                                               success: false,
                                                                               error_message: "API error"
                                                                             })
      end

      it "returns an error message" do
        post :create, params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include(
                                               "error" => "Failed to install webhook",
                                               "details" => "API error"
                                             )

        repository.reload
        expect(repository.webhook_installed).to be false
      end
    end
  end

  describe "DELETE #destroy" do
    let(:valid_params) { { repository_id: repository.id } }

    before do
      repository.update(
        webhook_installed: true,
        webhook_secret: "secret123",
        github_webhook_id: "webhook123"
      )

      allow(Github::WebhookService).to receive(:delete_webhook).and_return({
                                                                             success: true
                                                                           })
    end

    context "with valid parameters" do
      it "removes the webhook for the repository" do
        delete :destroy, params: valid_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
                                               "message" => "Webhook successfully removed",
                                               "repository_id" => repository.id,
                                               "webhook_installed" => false
                                             )

        repository.reload
        expect(repository.webhook_installed).to be false
        expect(repository.webhook_secret).to be_nil
        expect(repository.github_webhook_id).to be_nil
      end
    end

    context "when the repository has no webhook" do
      before do
        repository.update(webhook_installed: false, webhook_secret: nil, github_webhook_id: nil)
      end

      it "returns a message that no webhook is installed" do
        delete :destroy, params: valid_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
                                               "message" => "No webhook installed",
                                               "repository_id" => repository.id,
                                               "webhook_installed" => false
                                             )

        # Should not call the webhook service
        expect(Github::WebhookService).not_to have_received(:delete_webhook)
      end
    end

    context "when the repository is not found" do
      it "returns a not found error" do
        delete :destroy, params: { repository_id: 9999 }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include("error" => "Repository not found")
      end
    end

    context "when the user does not have permission" do
      let(:other_repository) { create(:github_repository, author_username: "other_user") }

      before do
        other_repository.update(webhook_installed: true, webhook_secret: "secret")
      end

      it "returns an unauthorized error" do
        delete :destroy, params: { repository_id: other_repository.id }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
                                               "error" => "Unauthorized to remove webhooks from this repository"
                                             )
      end
    end

    context "when GitHub API returns an error" do
      before do
        allow(Github::WebhookService).to receive(:delete_webhook).and_return({
                                                                               success: false,
                                                                               error_message: "API error"
                                                                             })
      end

      it "returns an error message" do
        delete :destroy, params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include(
                                               "error" => "Failed to remove webhook",
                                               "details" => "API error"
                                             )

        repository.reload
        expect(repository.webhook_installed).to be true
      end
    end

    context "when GitHub can't find the webhook" do
      before do
        allow(Github::WebhookService).to receive(:delete_webhook).and_return({
                                                                               not_found: true
                                                                             })
      end

      it "still clears the webhook data" do
        delete :destroy, params: valid_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
                                               "message" => "Webhook successfully removed",
                                               "repository_id" => repository.id,
                                               "webhook_installed" => false
                                             )

        repository.reload
        expect(repository.webhook_installed).to be false
        expect(repository.webhook_secret).to be_nil
      end
    end
  end

  describe "POST #receive_event" do
    let(:webhook_secret) { "test_webhook_secret" }
    let(:repository) { create(:github_repository, webhook_installed: true, webhook_secret: webhook_secret) }
    let(:payload) do
      {
        repository: {
          full_name: repository.full_name
        },
        action: "opened",
        issue: {
          number: 123,
          title: "Test issue",
          html_url: "https://github.com/test/repo/issues/123",
          user: { login: "testuser" },
          node_id: "issue_node_id",
          created_at: "2025-01-01T00:00:00Z",
          updated_at: "2025-01-01T00:00:00Z",
          comments: 0
        }
      }.to_json
    end

    before do
      allow(WebhookEventProcessorWorker).to receive(:perform_async)

      # Skip authentication for webhook endpoint
      request.headers["X-GitHub-Event"] = "issues"
      request.headers["X-GitHub-Delivery"] = "delivery_id"

      # Calculate the signature
      signature = "sha256=" + OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        webhook_secret,
        payload
      )
      request.headers["X-Hub-Signature-256"] = signature
    end

    it "processes webhook events and returns 200 OK" do
      request.env['RAW_POST_DATA'] = payload # Set the raw post data for the request
      post :receive_event

      expect(response).to have_http_status(:ok)
      expect(WebhookEventProcessorWorker).to have_received(:perform_async).with(
        "issues",
        JSON.parse(payload),
        repository.id
      )
    end

    context "with invalid signature" do
      before do
        request.headers["X-Hub-Signature-256"] = "sha256=invalid"
      end

      it "returns unauthorized" do
        request.env['RAW_POST_DATA'] = payload
        post :receive_event

        expect(response).to have_http_status(:unauthorized)
        expect(WebhookEventProcessorWorker).not_to have_received(:perform_async)
      end
    end

    context "when repository is not found" do
      let(:payload) do
        {
          repository: {
            full_name: "unknown/repo"
          }
        }.to_json
      end

      before do
        # Calculate the signature for the new payload
        signature = "sha256=" + OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new('sha256'),
          webhook_secret,
          payload
        )
        request.headers["X-Hub-Signature-256"] = signature
      end

      it "logs warning and returns 200 OK" do
        request.env['RAW_POST_DATA'] = payload
        post :receive_event

        expect(response).to have_http_status(:ok)
        expect(WebhookEventProcessorWorker).not_to have_received(:perform_async)
      end
    end

    context "with malformed JSON" do
      let(:invalid_payload) { "{invalid_json" }

      it "returns bad request" do
        request.env['RAW_POST_DATA'] = invalid_payload
        post :receive_event

        expect(response).to have_http_status(:bad_request)
        expect(WebhookEventProcessorWorker).not_to have_received(:perform_async)
      end
    end

    context "in development with signature verification skipped" do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        request.headers["X-Hub-Signature-256"] = "invalid"
        valid_test_payload = { test: true, repository: { full_name: repository.full_name } }.to_json
        request.env['RAW_POST_DATA'] = valid_test_payload
      end

      it "processes the webhook when skip_signature_verification is present" do
        post :receive_event, params: { skip_signature_verification: true }

        expect(response).to have_http_status(:ok)
        expect(WebhookEventProcessorWorker).to have_received(:perform_async)
      end
    end
  end
end
