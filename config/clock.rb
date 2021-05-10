require 'clockwork'
require 'clockwork/database_events'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'boot.rb'))

# Force reconnection and reaping
ActiveRecord::Base.establish_connection(
  ActiveRecord::Base.connection_config.merge({ reconnect: true, reaping_frequency: 10 })
)

module Clockwork
  Clockwork.manager = DatabaseEvents::Manager.new

  # NOTE: According to Clockwork docs, the 'every' in sync_database_events just
  # reloads the models in case of changes, and doesn't affect the frequency with
  # which jobs are executed - but IN FACT, it does. Whenever it reloads, it also
  # restarts jobs, so if a job should run less frequently than the sync_freq
  # here, the job will still run at least every sync_freq seconds.
  #
  # (eg. if you wanted a job that runs once every 5 mins, BOTH the frequency of
  # the ClockworkEvent in the DB AND the sync_freq here need to be >= 5 mins)
  #
  # This should be less of an issue now that we're using Sidekiq with Unique Jobs
  sync_freq = (ENV['SYNC_DB_EVENTS_FREQUENCY_MINS'] || 1).to_i

  sync_database_events model: ClockworkEvent, every: sync_freq.minutes do |clockwork_event|
    logger.debug "Clockwork fired for #{clockwork_event.id} - #{clockwork_event.name}"

    # Because job is cached we need to retrieve a fresh copy from DB to see if it is indeed still running
    job = ClockworkEvent.find(clockwork_event.id)
    job.schedule
  end

  error_handler do |error|
    Airbrake.notify(error)
  end
end
