module Github
  class OauthService
    class << self
      def authenticate(code)
        token = get_tokens(code)[:access_token]

        client = Octokit::Client.new(access_token: token)
        return { is_authenticated: false } unless client.user_authenticated?

        user = get_or_create_user(client, token)
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
          access_token: result.access_token
        }
      end

      def get_or_create_user(client, token)
        github_user = client.user
        user = User.with_github_id(github_user.id).first

        is_new_user = user.nil?
        user ||= create_new_user(client)
        update_user_token(user, token)

        UserRepositoriesFetcherWorker.perform_async(user.id) if is_new_user
        UserContributionsFetcherWorker.perform_async(user.id)

        LoggerExtension.log(:info, "User Authentication", {
          github_id: github_user.id,
          username: github_user.login,
          action: is_new_user ? "new_user" : "existing_user"
        })

        user
      rescue ActiveRecord::RecordNotUnique => e
        LoggerExtension.log(:error, "User Creation Conflict", {
          message: e.message,
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

      def update_user_token(user, token)
        UserToken.upsert(
          {
            user_id: user.id,
            access_token: token
          },
          unique_by: :user_id
        )
      end
    end
  end
end
