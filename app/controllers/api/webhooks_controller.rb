module Api
class WebhooksController < ApplicationController
  include Api::Concerns::JwtAuthenticable
  skip_before_action :authenticate_user!, only: [ :receive_event ]

  def create
    @repository = find_repository
    return render_repository_not_found if @repository.nil?
    return render_unauthorized_webhook_access unless has_permission_for_repository?(@repository)
    return render_webhook_already_installed if @repository.webhook_installed?

    install_webhook
  end

  def destroy
    @repository = find_repository
    return render_repository_not_found if @repository.nil?
    return render_unauthorized_webhook_access unless has_permission_for_repository?(@repository)
    return render_no_webhook_installed unless @repository.webhook_installed?

    remove_webhook
  end

  def receive_event
    payload_body = read_and_reset_request_body

    begin
      payload = parse_payload(payload_body)
      repository = find_repository_from_payload(payload)

      if repository.nil?
        LoggerExtension.log(:error, "Webhook received for unknown repository")
        return head :not_found
      end

      unless verify_webhook_signature(payload_body, repository.webhook_secret)
        LoggerExtension.log(:error, "Invalid webhook signature")
        return head :unauthorized
      end

      enqueue_webhook_processing(payload, repository)
      head :ok
    rescue JSON::ParserError => e
      LoggerExtension.log(:error, "Invalid JSON in webhook payload", {
        error: e.message,
        context: "webhook_payload_parsing"
      })
      render_error("Invalid JSON payload", :bad_request)
    end
  end

  def show
    @repository = find_repository_by_id

    if @repository.nil?
      return render_error("Repository not found", :not_found)
    end

    unless has_permission_for_repository?(@repository)
      return render_error("Unauthorized to view webhooks for this repository", :unauthorized)
    end

    render json: {
      repository_id: @repository.id,
      repository_name: @repository.full_name,
      webhook_installed: @repository.webhook_installed,
      webhook_id: @repository.github_webhook_id,
      last_updated: @repository.updated_at
    }
  end

  private

  def find_repository_by_id
    GithubRepository.find_by(id: params[:repository_id])
  end

  def find_repository
    GithubRepository.find_by(id: params[:repository_id]) ||
      GithubRepository.find_by(full_name: params[:repository_full_name])
  end

  def install_webhook
    webhook_secret = SecureRandom.hex(20)
    result = Github::WebhookService.create_webhook(
      @repository,
      @current_user,
      webhook_secret,
      callback_url: webhook_callback_url
    )

    if result[:success]
      update_repository_with_webhook(webhook_secret, result[:webhook].id)
      render_webhook_installed
    else
      render_webhook_installation_failed(result[:error_message])
    end
  rescue => e
    LoggerExtension.log(:error, "Error creating webhook", {
      repository_id: params[:repository_id],
      repository_full_name: params[:repository_full_name],
      error: e.message,
      backtrace: e.backtrace.first(5)
    })
    render_unexpected_error
  end

  def remove_webhook
    result = Github::WebhookService.delete_webhook(
      @repository,
      @current_user.access_token
    )

    if result[:success] || result[:not_found]
      update_repository_without_webhook
      render_webhook_removed
    else
      render_webhook_removal_failed(result[:error_message])
    end
  rescue => e
    LoggerExtension.log(:error, "Error deleting webhook", {
      repository_id: params[:repository_id],
      error: e.message,
      backtrace: e.backtrace.first(5)
    })
    render_unexpected_error
  end

  def update_repository_with_webhook(webhook_secret, webhook_id)
    @repository.update(
      webhook_secret: webhook_secret,
      webhook_installed: true,
      github_webhook_id: webhook_id
    )
  end

  def update_repository_without_webhook
    @repository.update(
      webhook_secret: nil,
      webhook_installed: false,
      github_webhook_id: nil
    )
  end

  def read_and_reset_request_body
    payload_body = request.body.read
    request.body.rewind
    payload_body
  end

  def parse_payload(payload_body)
    JSON.parse(payload_body)
  end

  def find_repository_from_payload(payload)
    repository_name = payload.dig("repository", "full_name")
    GithubRepository.find_by(full_name: repository_name)
  end

  def enqueue_webhook_processing(payload, repository)
    WebhookEventProcessorWorker.perform_async(
      request.headers["X-GitHub-Event"],
      payload,
      repository.id
    )
  end

  def verify_webhook_signature(payload_body, webhook_secret)
    return false if webhook_secret.blank?

    signature_header = request.headers["X-Hub-Signature-256"]
    return false unless signature_header.present?

    signature = generate_signature(webhook_secret, payload_body)
    ActiveSupport::SecurityUtils.secure_compare(signature, signature_header)
  end

  def generate_signature(webhook_secret, payload_body)
    "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      webhook_secret,
      payload_body
    )
  end

  def render_repository_not_found
    render_error("Repository not found", :not_found)
  end

  def render_unauthorized_webhook_access
    render_error("Unauthorized to manage webhooks for this repository", :unauthorized)
  end

  def render_webhook_already_installed
    render json: {
      message: "Webhook already installed",
      repository_id: @repository.id,
      webhook_installed: true
    }
  end

  def render_webhook_installed
    render json: {
      message: "Webhook successfully installed",
      repository_id: @repository.id,
      webhook_installed: true
    }, status: :created
  end

  def render_webhook_installation_failed(error_message)
    render json: {
      error: "Failed to install webhook",
      details: error_message
    }, status: :unprocessable_entity
  end

  def render_no_webhook_installed
    render json: {
      message: "No webhook installed",
      repository_id: @repository.id,
      webhook_installed: false
    }
  end

  def render_webhook_removed
    render json: {
      message: "Webhook successfully removed",
      repository_id: @repository.id,
      webhook_installed: false
    }
  end

  def render_webhook_removal_failed(error_message)
    render json: {
      error: "Failed to remove webhook",
      details: error_message
    }, status: :unprocessable_entity
  end

  def render_unexpected_error
    render_error("An unexpected error occurred", :internal_server_error)
  end

  # TODO: Check for admin/write permissions using Github API
  def has_permission_for_repository?(repository)
    repository.author_username == @current_user.github_account.github_username
  end

  def webhook_callback_url
    host = ENV["APPLICATION_HOST"] || ENV["LOCAL_TUNNEL"]
    "https://#{host}/api/webhook"
  end
end
end
