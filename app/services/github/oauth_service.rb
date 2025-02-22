module Github
  class OauthService
    class << self
      def authenticate(code)
        tokens = get_tokens(code)
        client = Octokit::Client.new(access_token: tokens[:access_token])
        return { is_authenticated: false } unless client.user_authenticated?

        user = get_or_create_user(client, tokens)
        {
          is_authenticated: true,
          user: user
        }
      end

      def refresh_token(refresh_token)
        client =  Octokit::Client.new(client_id: ENV["GITHUB_APP_CLIENT_ID"], client_secret: ENV["GITHUB_APP_SECRET_KEY"])
        client.refresh_access_token(refresh_token)
      end

      private

      def get_tokens(code)
        client = Octokit::Client.new
        result = client.exchange_code_for_token(
          code,
          ENV["GITHUB_APP_CLIENT_ID"],
          ENV["GITHUB_APP_SECRET_KEY"]
        )

        {
          access_token: result.access_token,
          expires_in: result.expires_in,
          refresh_token: result.refresh_token
        }
      end

      def get_or_create_user(client, tokens)
        github_user = client.user
        user = User.with_github_id(github_user.id).first

        user ||= create_new_user(client)
        update_user_token(user, tokens)

        LoggerExtension.log(:info, "User Authentication", {
          github_id: github_user.id,
          username: github_user.login,
          action: user.persisted? ? "existing_user" : "new_user"
        })

        user
      rescue ActiveRecord::RecordNotUnique => e
        LoggerExtension.log(:error, "User Creation Conflict", {
          error_message: e.message,
          github_id: github_user.id
        })
        raise e
      end

      def create_new_user(client)
        ActiveRecord::Base.transaction do
          user = User.create!(
            email: client.user.email,
            account_status: :enabled
          )

          GithubAccount.create!(
            user: user,
            github_id: client.user.id,
            github_username: client.user.login,
            avatar_url: client.user.avatar_url,
          )

          UserStat.create!(
            user: user,
            reputation_points: 0
          )

          user
        end
      end

      def update_user_token(user, tokens)
        UserToken.upsert(
          {
            user_id: user.id,
            access_token: tokens[:access_token],
            refresh_token: tokens[:refresh_token],
            expires_at: Time.now.utc + tokens[:expires_in]
          },
          unique_by: :user_id
        )
      end
    end
  end
end
