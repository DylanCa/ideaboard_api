require 'rails_helper'

RSpec.describe Github::GraphqlExecutionService do
  describe '.execute_query' do
    let(:query) { Queries::UserQueries.user_data }
    let(:variables) { nil }
    let(:context) { nil }
    let(:repo_name) { 'test/repo' }
    let(:username) { 'test-user' }
    let(:repo) { create(:github_repository, full_name: repo_name) }
    let(:user) { create(:user) }

    before do
      allow(GithubRepository).to receive(:find_by_full_name).with(repo_name).and_return(repo)
      allow(Github::TokenSelectionService).to receive(:select_token).and_return([ user.id, 'access-token', :personal ])
      allow(Github.client).to receive(:query).and_return(OpenStruct.new(
        data: OpenStruct.new(
          viewer: OpenStruct.new(login: 'test-user'),
          rate_limit: OpenStruct.new(
            cost: 1,
            remaining: 4999,
            resetAt: Time.now + 1.hour,
            limit: 5000,
            used: 1
          )
        ),
        errors: nil
      ))
      allow(LoggerExtension).to receive(:log)
      allow(Github::RateLimitTrackingService).to receive(:extract_rate_limit_info).and_return({
                                                                                                used: 1,
                                                                                                remaining: 4999,
                                                                                                limit: 5000,
                                                                                                cost: 1,
                                                                                                reset_at: Time.now + 1.hour,
                                                                                                percentage_used: 0.02
                                                                                              })
      allow(Github::RateLimitTrackingService).to receive(:log_token_usage)
    end

    it 'executes the query and returns the response' do
      response = described_class.execute_query(query, variables, context, repo_name, username)

      expect(response.data.viewer.login).to eq('test-user')
      expect(Github::TokenSelectionService).to have_received(:select_token).with(repo, username)
      expect(Github.client).to have_received(:query).with(query, variables: variables, context: hash_including(token: 'access-token'))
      expect(LoggerExtension).to have_received(:log).with(:info, "GraphQL Query Execution", anything)
      expect(LoggerExtension).to have_received(:log).with(:info, "GraphQL Query Completed", anything)
      expect(Github::RateLimitTrackingService).to have_received(:extract_rate_limit_info)
      expect(Github::RateLimitTrackingService).to have_received(:log_token_usage)
    end

    context 'when there are errors in the response' do
      before do
        allow(Github.client).to receive(:query).and_return(OpenStruct.new(
          data: OpenStruct.new,
          errors: [ 'Error 1', 'Error 2' ]
        ))
      end

      it 'logs the errors and returns nil' do
        response = described_class.execute_query(query, variables, context, repo_name, username)

        expect(response).to be_nil
        expect(LoggerExtension).to have_received(:log).with(:error, "GraphQL Query Errors", anything)
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Github.client).to receive(:query).and_raise(StandardError.new("Test error"))
      end

      it 'logs the error and returns nil' do
        response = described_class.execute_query(query, variables, context, repo_name, username)

        expect(response).to be_nil
        expect(LoggerExtension).to have_received(:log).with(:error, "Unhandled GraphQL Error", anything)
      end
    end
  end
end
