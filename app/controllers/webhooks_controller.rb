# app/controllers/webhooks_controller.rb (updated with improved error handling)

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
      # Save the webhook secret and mark as installed
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

    # Check if webhook is not installed
    unless @repository.webhook_installed?
      return render json: {
        message: "No webhook installed",
        repository_id: @repository.id,
        webhook_installed: false
      }
    end

    # Delete webhook with GitHub API
    result = Github::WebhookService.delete_webhook(
      @repository,
      @current_user.access_token
    )

    if result[:success] || result[:not_found]
      # Clear webhook data regardless of whether it was found on GitHub
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
    payload_body = request.body.read || ""
    request.body.rewind

    if payload_body.blank?
      LoggerExtension.log(:warn, "Empty webhook payload received", {
        delivery_id: request.headers["X-GitHub-Delivery"],
        event: request.headers["X-GitHub-Event"]
      })

      payload = {}
    else
      begin
        payload = JSON.parse(payload_body)
      rescue JSON::ParserError => e
        LoggerExtension.log(:error, "Invalid JSON in webhook payload", { error: e.message })
        return head :bad_request
      end
    end

    # GitHub sends the event type in the X-GitHub-Event header
    github_event = request.headers["X-GitHub-Event"]
    github_delivery = request.headers["X-GitHub-Delivery"]

    LoggerExtension.log(:info, "Webhook received", {
      event: github_event,
      delivery_id: github_delivery,
      repository: payload.dig("repository", "full_name")
    })

    # Extract repository information from the payload
    repository_name = payload.dig("repository", "full_name")
    repository = GithubRepository.find_by(full_name: repository_name)

    if repository.nil?
      # Repository not found in our system, log and return
      LoggerExtension.log(:warn, "Webhook received for unknown repository", {
        repository: repository_name,
        event: github_event,
        delivery_id: github_delivery
      })
      return head :ok  # Return 200 OK even for unknown repos to avoid GitHub retries
    end

    # Verify webhook signature
    unless verify_webhook_signature(payload_body, repository.webhook_secret)
      LoggerExtension.log(:error, "Invalid webhook signature", {
        repository: repository_name,
        event: github_event,
        delivery_id: github_delivery
      })
      return head :unauthorized
    end

    # Process the event asynchronously
    WebhookEventProcessorWorker.perform_async(
      github_event,
      payload,
      repository.id
    )

    head :ok
  rescue => e
    LoggerExtension.log(:error, "Error processing webhook", {
      error: e.message,
      backtrace: e.backtrace.first(5)
    })

    # Still return 200 to avoid GitHub retries
    head :ok
  end

  private

  def has_permission_for_repository?(repository)
    # Simple check - user is the repository owner
    # Could be expanded to check for admin/write permissions using GitHub API
    repository.author_username == @current_user.github_account.github_username
  end

  def webhook_callback_url
    host = ENV["APPLICATION_HOST"] || ENV["LOCAL_TUNNEL"]
    "https://#{host}/api/webhook"
  end

  def verify_webhook_signature(payload_body, webhook_secret)
    return true if Rails.env.development? && params[:skip_signature_verification].present?
    return false if webhook_secret.blank?

    signature_header = request.headers["X-Hub-Signature-256"]
    return false unless signature_header.present?

    payload_to_verify = payload_body || ""

    signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      webhook_secret,
      payload_to_verify
    )

    # Constant-time comparison to prevent timing attacks
    ActiveSupport::SecurityUtils.secure_compare(signature, signature_header)
  end
end
