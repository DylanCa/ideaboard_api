module Api
  module Concerns
    module ResponseFormatter
      extend ActiveSupport::Concern
      def render_success(data, meta = {}, status = :ok)
        render json: {
          meta: meta,
          data: data,
          error: nil
        }, status: status
      end
      def render_error(message, status = :unprocessable_entity, details = {})
        error = {
          message: message,
          status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
        }
        error.merge!(details) if details.present?
        render json: { meta: {}, data: nil, error: error }, status: status
      end
    end
  end
end
