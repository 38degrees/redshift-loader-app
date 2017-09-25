class TableWorker
  include Sidekiq::Worker
  
  # Some jobs are time sensitive, so only retry once before cancelling.
  # The retry will be ~15s after the initial failure, according to Sidekiq docs:
  # https://github.com/mperham/sidekiq/wiki/Error-Handling#automatic-job-retry
  #
  # Also, only allow one instance per lock_name to be running at a time using sidekiq-unique-jobs
  sidekiq_options retry: 1,
                  unique: :until_and_while_executing,
                  unique_args: :unique_args

  # Lock on the lock_name arg
  def self.unique_args(args)
    [ args[1] ]
  end
  
  def perform(table_id, lock_name)
    Table.find(table_id).copy_now
  end
end
