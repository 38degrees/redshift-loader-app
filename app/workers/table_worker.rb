class TableWorker
  include Sidekiq::Worker
  
  # Some jobs are time sensitive, so only retry once before cancelling.
  # The retry will be ~15s after the initial failure, according to Sidekiq docs:
  # https://github.com/mperham/sidekiq/wiki/Error-Handling#automatic-job-retry
  #
  # Also, only allow one instance of each Table to be running at a time using sidekiq-unique-jobs
  # (use unique until_executing because we want a table copy to be able to schedule
  # another instance of itself in case there are too many rows to copy in one hit)
  sidekiq_options retry: 1,
                  unique: :until_executing,
                  unique_args: :unique_args

  def self.unique_args(args)
    [ args[0] ]
  end
  
  def perform(table_id)
    Table.find(table_id).copy_now
  end
end
