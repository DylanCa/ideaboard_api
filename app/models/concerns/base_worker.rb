module BaseWorker
  extend ActiveSupport::Concern

  included do
    include Sidekiq::Job

    sidekiq_options queue: :default, retry: 3

    def perform(*args)
      start_time = Time.current

      worker_name = self.class.name
      log_start(worker_name, args)

      begin
        result = execute(*args)
      rescue StandardError => e
        handle_error(e, worker_name, args)
        raise
      end

      execution_time = ((Time.current - start_time) * 1000).round(2)
      log_completion(worker_name, args, execution_time)

      result
    end
  end

  def execute(*args)
    raise NotImplementedError, "#{self.class.name} must implement #execute"
  end

  private

  def log_start(worker_name, args)
    LoggerExtension.log(:info, "Starting job", {
      worker: worker_name,
      arguments: args_for_logging(args),
      job_id: jid
    })
  end

  def log_completion(worker_name, args, execution_time)
    LoggerExtension.log(:info, "Job completed", {
      worker: worker_name,
      arguments: args_for_logging(args),
      execution_time: "#{execution_time}ms",
      job_id: jid
    })
  end

  def handle_error(error, worker_name, args)
    LoggerExtension.log(:error, "Job failed", {
      worker: worker_name,
      arguments: args_for_logging(args),
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace&.first(10),
      job_id: jid
    })
  end

  def args_for_logging(args)
    args.map do |arg|
      if arg.is_a?(ActiveRecord::Base)
        "#{arg.class.name}##{arg.id}"
      elsif arg.respond_to?(:to_s) && arg.to_s.length < 100
        arg
      else
        arg.class.name
      end
    end
  end
end
