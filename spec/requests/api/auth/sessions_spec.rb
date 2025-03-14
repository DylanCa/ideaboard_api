require 'swagger_helper'

RSpec.describe 'api/auth/sessions', type: :request do
  path '/api/auth/logout' do
    delete('delete session') do
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end
end
