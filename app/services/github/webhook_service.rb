module Github
  class WebhookService
    class << self
      def create_webhook(repository, user, webhook_secret, options = {})
        client = Octokit::Client.new(access_token: user.access_token)

        begin
          permission_level = client.permission_level(repository.full_name, user.github_username)[:permission]
          unless permission_level == "admin"
            return { success: false, message: "You need admin permission on this repository to install webhooks" }
          end
        rescue Octokit::Error => e
          return { success: false, message: "Failed to verify repository permissions: #{e.message}" }
        end

        config = {
          url: options[:callback_url],
          content_type: "json",
          secret: webhook_secret
        }

        events = [ "pull_request", "issues", "repository" ]

        begin
          webhook = client.create_hook(
            repository.full_name,
            "web",
            config,
            { events: events, active: true }
          )

          { success: true, webhook: webhook }
        rescue Octokit::Error => e
          handle_error(e, repository, "create")
        end
      end

      def delete_webhook(repository, access_token)
        client = Octokit::Client.new(access_token: access_token)

        begin
          if repository.github_webhook_id.present?
            client.remove_hook(repository.full_name, repository.github_webhook_id)
            { success: true }
          else
            webhooks = client.hooks(repository.full_name)
            callback_url = Rails.application.routes.url_helpers.webhook_events_url

            webhook = webhooks.find { |hook| hook.config.url == callback_url }

            if webhook
              client.remove_hook(repository.full_name, webhook.id)
              { success: true }
            else
              { not_found: true }
            end
          end
        rescue Octokit::NotFound
          { not_found: true }
        rescue Octokit::Error => e
          handle_error(e, repository, "delete")
        end
      end

      private

      def handle_error(e, repository, action)
        LoggerExtension.log(:error, "Failed to #{action} webhook", {
          repository: repository.full_name,
          error: e.message
        })

        { success: false, message: e.message }
      end
    end
  end
end
