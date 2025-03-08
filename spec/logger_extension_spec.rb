require 'rails_helper'

RSpec.describe LoggerExtension do
  describe '.log' do
    let(:message) { 'Test log message' }

    before do
      @logged_messages = []
      allow(Rails.logger).to receive(:debug) { |msg| @logged_messages << [ :debug, msg ] }
      allow(Rails.logger).to receive(:info)  { |msg| @logged_messages << [ :info, msg ] }
      allow(Rails.logger).to receive(:warn)  { |msg| @logged_messages << [ :warn, msg ] }
      allow(Rails.logger).to receive(:error) { |msg| @logged_messages << [ :error, msg ] }
      allow(Rails.logger).to receive(:fatal) { |msg| @logged_messages << [ :fatal, msg ] }
    end

    context 'when logging at different levels' do
      it 'logs debug messages' do
        described_class.log(:debug, message)
        expect(@logged_messages.first[0]).to eq(:debug)
        expect(@logged_messages.first[1]).to match(/\e\[34m#{message}\e\[0m/)
      end

      it 'logs info messages' do
        described_class.log(:info, message)
        expect(@logged_messages.first[0]).to eq(:info)
        expect(@logged_messages.first[1]).to match(/\e\[32m#{message}\e\[0m/)
      end

      it 'logs warn messages' do
        described_class.log(:warn, message)
        expect(@logged_messages.first[0]).to eq(:warn)
        expect(@logged_messages.first[1]).to match(/\e\[33m#{message}\e\[0m/)
      end

      it 'logs error messages' do
        described_class.log(:error, message)
        expect(@logged_messages.first[0]).to eq(:error)
        expect(@logged_messages.first[1]).to match(/\e\[31m#{message}\e\[0m/)
      end

      it 'logs fatal messages' do
        described_class.log(:fatal, message)
        expect(@logged_messages.first[0]).to eq(:fatal)
        expect(@logged_messages.first[1]).to match(/\e\[35m#{message}\e\[0m/)
      end

      it 'defaults to info for unknown log levels' do
        described_class.log(:unknown, message)
        expect(@logged_messages.first[0]).to eq(:info)
        expect(@logged_messages.first[1]).to match(/\e\[32m#{message}\e\[0m/)
      end
    end

    context 'when logging with context' do
      let(:context) { { user_id: 123, action: 'login' } }

      it 'includes context in the log message' do
        described_class.log(:info, message, context)
        expect(@logged_messages.first[1]).to match(/#{message} \| Context: {.*user_id: 123, action: "login".*}/)
      end
    end

    context 'when logging without context' do
      it 'logs the message without additional context' do
        described_class.log(:info, message)
        expect(@logged_messages.first[1]).to match(/\e\[32m#{message}\e\[0m/)
      end
    end
  end

  describe '.format_log_message' do
    it 'returns the message when no context is provided' do
      result = described_class.send(:format_log_message, 'Test message')
      expect(result).to eq('Test message')
    end

    it 'includes context when provided' do
      context = { user_id: 123, action: 'login' }
      result = described_class.send(:format_log_message, 'Test message', context)
      expect(result).to match(/Test message \| Context: {.*user_id: 123, action: "login".*}/)
    end
  end

  describe 'COLORS constant' do
    it 'defines color codes for different log levels' do
      expect(described_class::COLORS).to eq({
                                              debug: "\e[34m",  # Blue
                                              info:  "\e[32m",  # Green
                                              warn:  "\e[33m",  # Yellow
                                              error: "\e[31m",  # Red
                                              fatal: "\e[35m"   # Magenta
                                            })
    end
  end

  describe 'Rails logger configuration' do
    context 'when in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'sets up a logger with STDOUT output' do
        load 'lib/logger_extension.rb'
        expect(Rails.logger.instance_variable_get(:@logdev).dev).to eq(STDOUT)
      end
    end
  end
end
