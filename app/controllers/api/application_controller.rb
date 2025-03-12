require_relative "./concerns/jwt_authenticable"

module Api
  class ApplicationController < ActionController::API
    include JwtAuthenticable
    before_action :authenticate_user!
  end
end
