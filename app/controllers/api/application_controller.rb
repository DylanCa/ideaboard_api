require_relative "./concerns/jwt_authenticable"
require_relative "./concerns/response_formatter"
module Api
  class ApplicationController < ActionController::API
    include Api::Concerns::JwtAuthenticable
    include Api::Concerns::ResponseFormatter

    before_action :authenticate_user!
  end
end
