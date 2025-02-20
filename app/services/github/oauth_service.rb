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
          access_token_expires_in: result.expires_in,
          refresh_token: result.refresh_token,
          refresh_token_expires_in: result.refresh_token_expires_in
        }
      end

      def get_or_create_user(client, tokens)
        github_user = client.user
        user = User.with_github_id(github_user.id).first

        ActiveRecord::Base.transaction do
          user ||= create_new_user(client, tokens)
          update_user_tokens(user, tokens)
          user
        end
      rescue ActiveRecord::RecordNotUnique => e
        raise e
      end

      private

      def create_new_user(client, tokens)
        User.create!(
          email: client.user.email,
          account_status: :enabled,
          github_account_attributes: {
            github_id: client.user.id,
            github_username: client.user.login,
            avatar_url: client.user.avatar_url
          },
          user_stat_attributes: { reputation_points: 0 }
        )
      end

      def update_user_tokens(user, tokens)
        user.user_tokens.create!(
          access_token: tokens[:access_token],
          refresh_token: tokens[:refresh_token],
          expires_at: Time.now.utc + tokens[:refresh_token_expires_in]
        )
      end
    end
  end
end
