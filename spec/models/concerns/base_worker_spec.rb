require 'rails_helper'

# Create a test worker class that includes BaseWorker
class TestWorker
  include BaseWorker

  def execute(arg1, arg2 = nil)
    { status: 'success', arg1: arg1, arg2: arg2 }
  end
end

RSpec.describe BaseWorker do
  let(:worker) { TestWorker.new }
  let(:args) { [ 'test_arg', { key: 'value' } ] }

  before do
    allow(LoggerExtension).to receive(:log)
    allow(worker).to receive(:jid).and_return('test-jid-123')
  end

  describe '#perform' do
    it 'logs the start of the job' do
      worker.perform(*args)

      expect(LoggerExtension).to have_received(:log).with(
        :info,
        "Starting job",
        hash_including(
          worker: "TestWorker",
          arguments: kind_of(Array),
          job_id: 'test-jid-123'
        )
      )
    end

    it 'calls #execute with the provided arguments' do
      allow(worker).to receive(:execute).and_call_original

      result = worker.perform(*args)

      expect(worker).to have_received(:execute).with(*args)
      expect(result).to include(
                          status: 'success',
                          arg1: 'test_arg',
                          arg2: { key: 'value' }
                        )
    end

    it 'logs completion of the job' do
      worker.perform(*args)

      expect(LoggerExtension).to have_received(:log).with(
        :info,
        "Job completed",
        hash_including(
          worker: "TestWorker",
          arguments: kind_of(Array),
          execution_time: match(/\d+\.\d+ms/),
          job_id: 'test-jid-123'
        )
      )
    end

    context 'when an error occurs' do
      let(:error) { StandardError.new("Test error") }

      before do
        allow(worker).to receive(:execute).and_raise(error)
        allow(error).to receive(:backtrace).and_return(Array.new(15) { |i| "backtrace line #{i}" })
      end

      it 'logs the error and re-raises it' do
        expect {
          worker.perform(*args)
        }.to raise_error(StandardError, "Test error")

        expect(LoggerExtension).to have_received(:log).with(
          :error,
          "Job failed",
          hash_including(
            worker: "TestWorker",
            arguments: kind_of(Array),
            error_class: "StandardError",
            error_message: "Test error",
            backtrace: array_including("backtrace line 0"),
            job_id: 'test-jid-123'
          )
        )
      end
    end
  end

  describe '#execute' do
    it 'raises NotImplementedError when called on BaseWorker directly' do
      base_worker_class = Class.new do
        include BaseWorker
      end

      worker = base_worker_class.new

      expect {
        worker.execute
      }.to raise_error(NotImplementedError, /must implement #execute/)
    end
  end

  describe '#args_for_logging' do
    it 'formats ActiveRecord objects for logging' do
      record = instance_double(ActiveRecord::Base, id: 123, class: User)
      allow(record.class).to receive(:name).and_return('User')

      result = worker.send(:args_for_logging, [ record ])

      expect(result).to eq([ 'User#123' ])
    end

    it 'formats short strings directly' do
      result = worker.send(:args_for_logging, [ 'short string' ])

      expect(result).to eq([ 'short string' ])
    end

    it 'formats long objects as class names' do
      long_string = 'a' * 150

      result = worker.send(:args_for_logging, [ long_string ])

      expect(result).to eq([ 'String' ])
    end
  end
end
