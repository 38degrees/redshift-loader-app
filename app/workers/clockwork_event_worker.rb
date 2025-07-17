class ClockworkEventWorker
  include Sidekiq::Worker
  
  # Some jobs are time sensitive, so only retry once before cancelling.
  # The retry will be ~15s after the initial failure, according to Sidekiq docs:
  # https://github.com/mperham/sidekiq/wiki/Error-Handling#automatic-job-retry
  #
  # Also, only allow one instance of each ClockworkEvent to be running at a time using sidekiq-unique-jobs
  sidekiq_options retry: 1,
                  lock: :until_executed,
                  lock_args_method: :lock_args,
                  lock_ttl: 1.hour

  def self.lock_args(args)
    [args[0]]  # args is an array of perform method arguments, so we pick the first one
  end
  
  def perform(clockwork_event_id)
    ClockworkEvent.find(clockwork_event_id).perform
  end
end
