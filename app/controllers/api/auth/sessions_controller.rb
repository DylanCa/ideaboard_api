# app/controllers/api/auth/sessions_controller.rb
module Api
  module Auth
    class SessionsController < ApplicationController
      include Api::Concerns::JwtAuthenticable

      def destroy
        # Extract the current token
        token = extract_token

        # Add token to blacklist with expiry time
        blacklist_token(token)

        render_success({ message: "Successfully logged out" }, {}, :ok)
      end

      private

      # TODO: Find a better way to do so, not by caching stuff in Rails cache.
      def blacklist_token(token)
        # Decode the token to get its expiry time
        decoded_token = JwtService.decode(token)
        exp_time = decoded_token["exp"]

        # Store in Redis with expiry set to token's expiration
        expires_in = [ exp_time - Time.now.to_i, 0 ].max.seconds
        Rails.cache.write("blacklisted_token:#{token}", Time.now.to_i, expires_in: expires_in)
      end
    end
  end
end
