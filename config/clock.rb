require 'clockwork'
require 'clockwork/database_events'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'boot.rb'))

# Force reconnection and reaping
ActiveRecord::Base.establish_connection(
    ActiveRecord::Base.connection_config.merge({reconnect: true, reaping_frequency: 10})
    )

module Clockwork

  Clockwork.manager = DatabaseEvents::Manager.new

  sync_database_events model: ClockworkEvent, every: 1.minutes do |clockwork_event|

    # Because job is cached we need to retrieve a fresh copy from DB to see if it is indeed still running
    job = ClockworkEvent.find(clockwork_event.id)

    if job.running && (DateTime.now - job.last_run_at.to_datetime) * 1.day > 1.hour
        job.running = false
        job.save
        logger.info "ClockworkEvent '#{job.name}' stuck in running state for 1 hour - resetting..."
    end

    if !job.running
        if job.queue
            job.delay(:queue => job.queue).perform
        else
            job.delay.perform
        end
    end
  end

  error_handler do |error|
    Airbrake.notify(error)
  end

end