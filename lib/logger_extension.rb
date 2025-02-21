module LoggerExtension
  # ANSI color codes
  COLORS = {
    debug: "\e[34m",  # Blue
    info:  "\e[32m",  # Green
    warn:  "\e[33m",  # Yellow
    error: "\e[31m",  # Red
    fatal: "\e[35m"   # Magenta
  }

  RESET_COLOR = "\e[0m"

  def self.log(level, message, context = {})
    # Colorize the message based on log level
    color_code = COLORS[level] || COLORS[:info]
    formatted_message = "#{color_code}#{format_log_message(message, context)}#{RESET_COLOR}"

    # Use the appropriate Rails logger method
    case level
    when :debug
      Rails.logger.debug(formatted_message)
    when :info
      Rails.logger.info(formatted_message)
    when :warn
      Rails.logger.warn(formatted_message)
    when :error
      Rails.logger.error(formatted_message)
    when :fatal
      Rails.logger.fatal(formatted_message)
    else
      Rails.logger.info(formatted_message)
    end
  end

  private

  def self.format_log_message(message, context = {})
    if context.any?
      "#{message} | Context: #{context.inspect}"
    else
      message
    end
  end
end

# Modify Rails logger configuration to support color
if Rails.env.development?
  Rails.logger = ActiveSupport::Logger.new(STDOUT)
  Rails.logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime.strftime("%Y-%m-%d %H:%M:%S")} #{severity} -- : #{msg}\n"
  end
end