class JwtService
  SECRET_KEY = ENV["JWT_SECRET_KEY"] || raise("JWT Secret not configured")

  def self.encode(payload, expiration: nil)
    payload[:exp] = (expiration || Time.now.to_i + default_expiration)
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  def self.decode(token)
    decoded_token = JWT.decode(
      token,
      SECRET_KEY,
      true,
      { algorithm: 'HS256' }
    ).first

    validate_token(decoded_token)

    decoded_token
  rescue JWT::ExpiredSignature
    raise AuthenticationError, "Token has expired"
  rescue JWT::DecodeError => e
    raise AuthenticationError, "Invalid token: #{e.message}"
  end

  private

  def self.default_expiration
    ENV.fetch('JWT_EXPIRATION', 1.week).to_i
  end

  def self.validate_token(decoded_token)
    raise AuthenticationError, "Missing user ID" unless decoded_token['user_id']
  end
end

# Custom error class for more specific error handling
class AuthenticationError < StandardError; end
