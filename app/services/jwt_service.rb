class JwtService
  SECRET_KEY = ENV['JWT_SECRET_KEY']
  EXPIRATION = ENV['JWT_EXPIRATION'].to_i

  def self.encode(payload)
    payload[:exp] = Time.now.to_i + EXPIRATION
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    JWT.decode(token, SECRET_KEY, true).first
  rescue JWT::ExpiredSignature
    raise 'Token expired'
  rescue JWT::DecodeError
    raise 'Invalid token'
  end
end
