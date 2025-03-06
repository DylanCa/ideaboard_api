require 'rails_helper'

RSpec.describe RateLimitMonitoringWorker do
  describe '#execute' do
    context 'when there are tokens with low rate limits' do
      let(:low_limit_tokens) { { [ 'User', 1 ] => 3, [ 'User', 2 ] => 2 } }

      before do
        allow(RateLimitLog).to receive_message_chain(:where, :where, :group, :count).and_return(low_limit_tokens)
      end

      it 'returns information about tokens with low rate limits' do
        result = subject.execute

        expect(RateLimitLog).to have_received(:where).with("created_at > ?", 1.hour.ago)
        expect(RateLimitLog).to have_received(:where).with("remaining_points < 1000")

        expect(result).to include(
                            low_limit_tokens_count: 2,
                            tokens: low_limit_tokens.keys
                          )
      end
    end

    context 'when there are no tokens with low rate limits' do
      before do
        allow(RateLimitLog).to receive_message_chain(:where, :where, :group, :count).and_return({})
      end

      it 'returns a status message' do
        result = subject.execute

        expect(result).to include(
                            status: "ok",
                            low_limit_tokens_count: 0
                          )
      end
    end
  end
end
