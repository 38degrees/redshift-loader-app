class TableWorker
  include Sidekiq::Worker
  
  # Some jobs are time sensitive, so only retry once before cancelling.
  # The retry will be ~15s after the initial failure, according to Sidekiq docs:
  # https://github.com/mperham/sidekiq/wiki/Error-Handling#automatic-job-retry
  #
  # Also, only allow one instance per lock_name to be running at a time using sidekiq-unique-jobs
sidekiq_options retry: 1,
                lock: :until_executed,
                lock_args_method: :lock_args,
                lock_ttl: 1.hour

  # Lock on the lock_name arg
  def self.lock_args(args)
    [args[1]]
  end
  
  def perform(table_id, lock_name)
    @table_id = table_id
    @lock_name = lock_name
  
    logger.info "[perform] START for jid=#{jid}, table_id=#{@table_id}, lock_name=#{@lock_name}"
  
    t = Table.find(@table_id)
    rows_copied = t.copy_now
  
    run_again = (rows_copied >= t.import_row_limit)
    logger.info "[perform] FINISH for jid=#{jid}, table_id=#{@table_id}, lock_name=#{@lock_name}, run_again=#{run_again}"
  
    # Should schedule again if we hit the row limit, as there are more rows to copy
    # The until_executed lock is still in play here, so do the scheduling in after_unlock
    if run_again
      logger.info "[perform] run_again=true — re-enqueuing for table_id=#{@table_id}, lock_name=#{@lock_name}"
      TableWorker.perform_async(@table_id, @lock_name)
    else
      logger.info "[perform] run_again=false — no re-enqueue"
    end
  end
end
