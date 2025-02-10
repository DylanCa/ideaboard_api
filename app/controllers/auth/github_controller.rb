module Auth
  class GithubController < ApplicationController
    def callback
      code = params[:code]
      res = Github::OauthService.authenticate(code)

      if res[:is_authenticated]
        user = res[:user]

        payload = {
          user_id: user.id,
          github_username: user.github_account.github_username,
          iat: Time.now.to_i
        }

        jwt_token = JwtService.encode(payload)
        render json: { jwt_token: jwt_token,
                       user: user,
                       github_account: user.github_account,
                       user_stat: user.user_stat }
      else
        # TODO: Stuff here
        raise
      end
    end
  end
end
