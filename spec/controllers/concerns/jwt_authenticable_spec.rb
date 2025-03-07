require 'rails_helper'

RSpec.describe JwtService do
  let(:user_id) { 123 }
  let(:github_username) { 'test-user' }
  let(:payload) { { user_id: user_id, github_username: github_username, iat: Time.now.to_i } }
  let(:secret_key) { 'test-secret-key' }

  before do
    # Mock SECRET_KEY directly
    stub_const("SECRET_KEY", secret_key)

    # Still mock ENV.fetch for JWT_EXPIRATION
    allow(ENV).to receive(:fetch).with("JWT_EXPIRATION", 1.week).and_return(1.week)
  end

  describe '.encode' do
    it 'encodes a payload into a JWT token' do
      token = described_class.encode(payload)
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # Header, payload, signature
    end

    it 'adds expiration time to payload' do
      allow(JWT).to receive(:encode).and_call_original

      described_class.encode(payload)

      expect(JWT).to have_received(:encode) do |encoded_payload, *args|
        expect(encoded_payload).to include(
                                     user_id: user_id,
                                     github_username: github_username
                                   )
        expect(encoded_payload[:exp]).to be_a(Integer)
      end
    end

    context 'with custom expiration time' do
      it 'uses the provided expiration time' do
        expiration_time = Time.now.to_i + 30.minutes
        allow(JWT).to receive(:encode).and_call_original

        described_class.encode(payload, expiration: expiration_time)

        expect(JWT).to have_received(:encode) do |encoded_payload, *args|
          expect(encoded_payload[:exp]).to eq(expiration_time)
        end
      end
    end
  end

  describe '.decode' do
    let(:token) { described_class.encode(payload) }

    it 'decodes a JWT token' do
      decoded_payload = described_class.decode(token)
      expect(decoded_payload['user_id']).to eq(user_id)
      expect(decoded_payload['github_username']).to eq(github_username)
    end

    context 'with expired token' do
      it 'raises an AuthenticationError' do
        allow(JWT).to receive(:decode).and_raise(JWT::ExpiredSignature)

        expect {
          described_class.decode(token)
        }.to raise_error(AuthenticationError, 'Token has expired')
      end
    end

    context 'with invalid token format' do
      it 'raises an AuthenticationError' do
        allow(JWT).to receive(:decode).and_raise(JWT::DecodeError.new("Invalid token"))

        expect {
          described_class.decode(token)
        }.to raise_error(AuthenticationError, /Invalid token/)
      end
    end

    context 'with missing user_id' do
      it 'raises an AuthenticationError' do
        # Mock a valid JWT decode but with a payload missing user_id
        allow(JWT).to receive(:decode).and_return([ { 'github_username' => github_username } ])

        expect {
          described_class.decode(token)
        }.to raise_error(AuthenticationError, 'Missing user ID')
      end
    end
  end

  describe '.default_expiration' do
    it 'returns the value from ENV' do
      expect(ENV).to receive(:fetch).with('JWT_EXPIRATION', 1.week).and_return(2.weeks.to_i)
      expect(described_class.send(:default_expiration)).to eq(2.weeks.to_i)
    end
  end

  describe 'AuthenticationError' do
    it 'is a StandardError' do
      expect(AuthenticationError.ancestors).to include(StandardError)
    end
  end
end
