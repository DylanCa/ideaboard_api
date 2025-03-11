class WebhooksController < ApplicationController
  include JwtAuthenticable
  skip_before_action :authenticate_user!, only: [ :receive_event ]

  def create
    @repository = GithubRepository.find_by(id: params[:repository_id]) ||
      GithubRepository.find_by(full_name: params[:repository_full_name])

    if @repository.nil?
      return render json: { error: "Repository not found" }, status: :not_found
    end

    unless has_permission_for_repository?(@repository)
      return render json: { error: "Unauthorized to add webhooks to this repository" }, status: :unauthorized
    end

    if @repository.webhook_installed?
      return render json: {
        message: "Webhook already installed",
        repository_id: @repository.id,
        webhook_installed: true
      }
    end

    webhook_secret = SecureRandom.hex(20)
    result = Github::WebhookService.create_webhook(
      @repository,
      @current_user.access_token,
      webhook_secret,
      callback_url: webhook_callback_url
    )

    if result[:success]
      @repository.update(
        webhook_secret: webhook_secret,
        webhook_installed: true,
        github_webhook_id: result[:webhook].id
      )

      render json: {
        message: "Webhook successfully installed",
        repository_id: @repository.id,
        webhook_installed: true
      }, status: :created
    else
      render json: {
        error: "Failed to install webhook",
        details: result[:error_message]
      }, status: :unprocessable_entity
    end
  rescue => e
    LoggerExtension.log(:error, "Error creating webhook", {
      repository_id: params[:repository_id],
      repository_full_name: params[:repository_full_name],
      error: e.message,
      backtrace: e.backtrace.first(5)
    })

    render json: { error: "An unexpected error occurred" }, status: :internal_server_error
  end

  def destroy
    @repository = GithubRepository.find_by(id: params[:repository_id])

    if @repository.nil?
      return render json: { error: "Repository not found" }, status: :not_found
    end

    unless has_permission_for_repository?(@repository)
      return render json: { error: "Unauthorized to remove webhooks from this repository" }, status: :unauthorized
    end

    unless @repository.webhook_installed?
      return render json: {
        message: "No webhook installed",
        repository_id: @repository.id,
        webhook_installed: false
      }
    end

    result = Github::WebhookService.delete_webhook(
      @repository,
      @current_user.access_token
    )

    if result[:success] || result[:not_found]
      @repository.update(
        webhook_secret: nil,
        webhook_installed: false,
        github_webhook_id: nil
      )

      render json: {
        message: "Webhook successfully removed",
        repository_id: @repository.id,
        webhook_installed: false
      }
    else
      render json: {
        error: "Failed to remove webhook",
        details: result[:error_message]
      }, status: :unprocessable_entity
    end
  rescue => e
    LoggerExtension.log(:error, "Error deleting webhook", {
      repository_id: params[:repository_id],
      error: e.message,
      backtrace: e.backtrace.first(5)
    })

    render json: { error: "An unexpected error occurred" }, status: :internal_server_error
  end

  def receive_event
    payload_body = request.body.read
    request.body.rewind

    payload = JSON.parse(payload_body)

    github_event = request.headers["X-GitHub-Event"]

    repository_name = payload.dig("repository", "full_name")
    repository = GithubRepository.find_by(full_name: repository_name)

    if repository.nil?
      LoggerExtension.log(:warn, "Webhook received for unknown repository")
      return head :not_found
    end

    unless verify_webhook_signature(payload_body, repository.webhook_secret)
      LoggerExtension.log(:error, "Invalid webhook signature")
      return head :unauthorized
    end

    WebhookEventProcessorWorker.perform_async(
      github_event,
      payload,
      repository.id
    )

    head :ok
  rescue JSON::ParserError => e
    LoggerExtension.log(:error, "Invalid JSON in webhook payload", { error: e.message })
    render json: { error: "Invalid JSON payload" }, status: :bad_request
  end

  private

  def verify_webhook_signature(payload_body, webhook_secret)
    return false if webhook_secret.blank?

    signature_header = request.headers["X-Hub-Signature-256"]
    return false unless signature_header.present?

    signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      webhook_secret,
      payload_body
    )

    ActiveSupport::SecurityUtils.secure_compare(signature, signature_header)
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
