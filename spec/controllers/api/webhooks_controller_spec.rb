require 'rails_helper'

RSpec.describe Api::WebhooksController, type: :controller do
  let(:user) { create(:user, :with_github_account, :with_access_token) }
  let(:repository) { create(:github_repository, author_username: user.github_account.github_username) }

  before do
    setup_authentication
    setup_request_headers
  end

  describe "POST #create" do
    let(:valid_params) { { repository_id: repository.id } }

    context "with valid parameters" do
      before { mock_successful_webhook_creation }

      it "creates a webhook for the repository" do
        perform_webhook_creation

        expect_successful_webhook_creation_response
        expect_repository_updated_after_creation
      end
    end

    context "when the repository already has a webhook" do
      before do
        repository.update(webhook_installed: true, webhook_secret: "existing_secret")
        allow(Github::WebhookService).to receive(:create_webhook)
      end

      it "returns a message that webhook is already installed" do
        perform_webhook_creation

        expect_webhook_already_installed_response
        expect(Github::WebhookService).not_to have_received(:create_webhook)
      end
    end

    context "when the repository is not found" do
      it "returns a not found error" do
        post :create, params: { repository_id: 9999 }

        expect_not_found_response
      end
    end

    context "when the user does not have permission" do
      let(:other_repository) { create(:github_repository, author_username: "other_user") }

      it "returns an unauthorized error" do
        post :create, params: { repository_id: other_repository.id }

        expect_unauthorized_response
      end
    end

    context "when GitHub API returns an error" do
      before { mock_webhook_creation_failure }

      it "returns an error message" do
        perform_webhook_creation

        expect_webhook_creation_failure_response
        expect_repository_not_updated_after_failure
      end
    end
  end

  describe "DELETE #destroy" do
    let(:valid_params) { { repository_id: repository.id } }

    before { setup_repository_with_webhook }

    context "with valid parameters" do
      before { mock_successful_webhook_deletion }

      it "removes the webhook for the repository" do
        perform_webhook_deletion

        expect_successful_webhook_removal_response
        expect_repository_updated_after_deletion
      end
    end

    context "when the repository has no webhook" do
      before do
        repository.update(webhook_installed: false, webhook_secret: nil, github_webhook_id: nil)
        allow(Github::WebhookService).to receive(:delete_webhook)
      end

      it "returns a message that no webhook is installed" do
        perform_webhook_deletion

        expect_no_webhook_installed_response
        expect(Github::WebhookService).not_to have_received(:delete_webhook)
      end
    end

    context "when the repository is not found" do
      it "returns a not found error" do
        delete :destroy, params: { repository_id: 9999 }

        expect_not_found_response
      end
    end

    context "when the user does not have permission" do
      let(:other_repository) { create(:github_repository, author_username: "other_user") }

      before { other_repository.update(webhook_installed: true, webhook_secret: "secret") }

      it "returns an unauthorized error" do
        delete :destroy, params: { repository_id: other_repository.id }

        expect_unauthorized_response
      end
    end

    context "when GitHub API returns an error" do
      before { mock_webhook_deletion_failure }

      it "returns an error message" do
        perform_webhook_deletion

        expect_webhook_removal_failure_response
        expect_repository_not_updated_after_deletion_failure
      end
    end

    context "when GitHub can't find the webhook" do
      before { mock_webhook_not_found }

      it "still clears the webhook data" do
        perform_webhook_deletion

        expect_successful_webhook_removal_response
        expect_repository_updated_after_deletion
      end
    end
  end

  describe "POST #receive_event" do
    let(:webhook_secret) { "test_webhook_secret" }
    let(:repository) { create(:github_repository, webhook_installed: true, webhook_secret: webhook_secret) }

    let(:payload) { build_webhook_payload(repository) }

    before { setup_webhook_event_request(webhook_secret, payload) }

    it "processes webhook events and returns 200 OK" do
      post_webhook_event(payload)

      expect_successful_webhook_event_processing
    end

    context "with invalid signature" do
      before { setup_invalid_signature }

      it "returns unauthorized" do
        post_webhook_event(payload)

        expect_unauthorized_webhook_event
      end
    end

    context "when repository is not found" do
      let(:payload) { build_unknown_repository_payload }

      before { setup_unknown_repository_signature(webhook_secret, payload) }

      it "logs warning and returns 404 OK" do
        post_webhook_event(payload)

        expect_repository_not_found_webhook_event
      end
    end

    context "with malformed JSON" do
      let(:invalid_payload) { "{invalid_json" }

      it "returns bad request" do
        post_webhook_event(invalid_payload)

        expect_bad_request_webhook_event
      end
    end
  end

  private

  def setup_authentication
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::Concerns::JwtAuthenticable).to receive(:extract_token).and_return("test-token")
    allow(JwtService).to receive(:decode).and_return({ "user_id" => user.id, "github_username" => user.github_account.github_username })
    controller.instance_variable_set(:@current_user, user)
  end

  def setup_request_headers
    request.headers['CONTENT_TYPE'] = 'application/json'
  end

  def mock_successful_webhook_creation
    allow(Github::WebhookService).to receive(:create_webhook).with(
      repository,
      anything,
      anything,
      hash_including(:callback_url)
    ).and_return({
                   success: true,
                   webhook: OpenStruct.new(id: "webhook123")
                 })
  end

  def perform_webhook_creation
    post :create, params: valid_params
  end

  def expect_successful_webhook_creation_response
    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)).to include(
                                           "message" => "Webhook successfully installed",
                                           "repository_id" => repository.id,
                                           "webhook_installed" => true
                                         )
  end

  def expect_repository_updated_after_creation
    repository.reload
    expect(repository.webhook_installed).to be true
    expect(repository.webhook_secret).not_to be_nil
    expect(repository.github_webhook_id).to eq("webhook123")
  end

  def expect_webhook_already_installed_response
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include(
                                           "message" => "Webhook already installed",
                                           "repository_id" => repository.id,
                                           "webhook_installed" => true
                                         )
  end

  def expect_not_found_response
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to include("error" => "Repository not found")
  end

  def expect_unauthorized_response
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include(
                                           "error" => "Unauthorized to manage webhooks for this repository"
                                         )
  end

  def mock_webhook_creation_failure
    allow(Github::WebhookService).to receive(:create_webhook).and_return({
                                                                           success: false,
                                                                           error_message: "API error"
                                                                         })
  end

  def expect_webhook_creation_failure_response
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to include(
                                           "error" => "Failed to install webhook",
                                           "details" => "API error"
                                         )
  end

  def expect_repository_not_updated_after_failure
    repository.reload
    expect(repository.webhook_installed).to be false
  end

  def setup_repository_with_webhook
    repository.update(
      webhook_installed: true,
      webhook_secret: "secret123",
      github_webhook_id: "webhook123"
    )
  end

  def mock_successful_webhook_deletion
    allow(Github::WebhookService).to receive(:delete_webhook).and_return({
                                                                           success: true
                                                                         })
  end

  def perform_webhook_deletion
    delete :destroy, params: valid_params
  end

  def expect_successful_webhook_removal_response
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include(
                                           "message" => "Webhook successfully removed",
                                           "repository_id" => repository.id,
                                           "webhook_installed" => false
                                         )
  end

  def expect_repository_updated_after_deletion
    repository.reload
    expect(repository.webhook_installed).to be false
    expect(repository.webhook_secret).to be_nil
    expect(repository.github_webhook_id).to be_nil
  end

  def expect_no_webhook_installed_response
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include(
                                           "message" => "No webhook installed",
                                           "repository_id" => repository.id,
                                           "webhook_installed" => false
                                         )
  end

  def mock_webhook_deletion_failure
    allow(Github::WebhookService).to receive(:delete_webhook).and_return({
                                                                           success: false,
                                                                           error_message: "API error"
                                                                         })
  end

  def expect_webhook_removal_failure_response
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to include(
                                           "error" => "Failed to remove webhook",
                                           "details" => "API error"
                                         )
  end

  def expect_repository_not_updated_after_deletion_failure
    repository.reload
    expect(repository.webhook_installed).to be true
  end

  def mock_webhook_not_found
    allow(Github::WebhookService).to receive(:delete_webhook).and_return({
                                                                           not_found: true
                                                                         })
  end

  def build_webhook_payload(repository)
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

  def setup_webhook_event_request(webhook_secret, payload)
    allow(WebhookEventProcessorWorker).to receive(:perform_async)

    request.headers["X-GitHub-Event"] = "issues"
    request.headers["X-GitHub-Delivery"] = "delivery_id"

    signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      webhook_secret,
      payload
    )
    request.headers["X-Hub-Signature-256"] = signature
  end

  def post_webhook_event(payload)
    post :receive_event, body: payload
  end

  def expect_successful_webhook_event_processing
    expect(response).to have_http_status(:ok)
    expect(WebhookEventProcessorWorker).to have_received(:perform_async).with(
      "issues",
      JSON.parse(payload),
      repository.id
    )
  end

  def setup_invalid_signature
    request.headers["X-Hub-Signature-256"] = "sha256=invalid"
  end

  def expect_unauthorized_webhook_event
    expect(response).to have_http_status(:unauthorized)
    expect(WebhookEventProcessorWorker).not_to have_received(:perform_async)
  end

  def build_unknown_repository_payload
    {
      repository: {
        full_name: "unknown/repo"
      }
    }.to_json
  end

  def setup_unknown_repository_signature(webhook_secret, payload)
    signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      webhook_secret,
      payload
    )
    request.headers["X-Hub-Signature-256"] = signature
  end

  def expect_repository_not_found_webhook_event
    expect(response).to have_http_status(:not_found)
    expect(WebhookEventProcessorWorker).not_to have_received(:perform_async)
  end

  def expect_bad_request_webhook_event
    expect(response).to have_http_status(:bad_request)
    expect(WebhookEventProcessorWorker).not_to have_received(:perform_async)
  end
end
