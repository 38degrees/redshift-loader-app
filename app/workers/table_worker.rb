class TableWorker
  include Sidekiq::Worker
  
  # Some jobs are time sensitive, so only retry once before cancelling.
  # The retry will be ~15s after the initial failure, according to Sidekiq docs:
  # https://github.com/mperham/sidekiq/wiki/Error-Handling#automatic-job-retry
  #
  # Also, only allow one instance per lock_name to be running at a time using sidekiq-unique-jobs
  sidekiq_options retry: 1,
                  unique: :until_executed,
                  unique_args: :unique_args,
                  lock_expiration: (1 * 60 * 60)  # 1 hour

  # Lock on the lock_name arg
  def self.unique_args(args)
    [ args[1] ]
  end
  
  def perform(table_id, lock_name)
    @table_id = table_id
    @lock_name = lock_name
    
    logger.info "STARTING job for jid=#{jid}, table_id=#{@table_id}, lock_name=#{@lock_name}"
    t = Table.find(@table_id)
    rows_copied = t.copy_now
    
    # Should schedule again if we hit the row limit, as there are more rows to copy.
    # The until_executed lock is still in play here, so do the scheduling in after_unlock
    @run_again = (rows_copied >= t.import_row_limit)
    logger.info "FINISHED job for jid=#{jid}, table_id=#{@table_id}, lock_name=#{@lock_name}"
  end
  
  # Sidekiq Unique Jobs hook - run once block has yielded and lock is released.
  # Need to schedule anotehr run AFTER unique lock is released
  def after_unlock
    logger.info "[after_unlock] Hook triggered for table_id=#{@table_id}, lock_name=#{@lock_name}, run_again=#{@run_again.inspect}"
  
    if @run_again
      logger.info "[after_unlock] @run_again is true — re-enqueuing TableWorker for table_id=#{@table_id}, lock_name=#{@lock_name}"
      TableWorker.perform_async(@table_id, @lock_name)
    else
      logger.info "[after_unlock] @run_again is false — no re-enqueue for table_id=#{@table_id}"
    end
  end
end
