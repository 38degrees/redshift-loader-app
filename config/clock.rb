require 'clockwork'
require 'clockwork/database_events'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'boot.rb'))

module Clockwork

  Clockwork.manager = DatabaseEvents::Manager.new

  sync_database_events model: ClockworkEvent, every: 1.minute do |clockwork_event|

    # Because job is cached we need to retrieve a fresh copy from DB to see if it is indeed still running
    job = ClockworkEvent.find(clockwork_event.id)

    #clear running state if has been over 1 hour
    if job.running && (DateTime.now - job.last_run_at.to_datetime) * 1.day > 1.hour
        job.running = false
        job.save
        logger.info "ClockworkEvent '#{job.name}' stuck in running state for 1 hour - resetting..."
    end

    #restart the jobs
    if !job.running
        if job.queue
            job.delay(:queue => job.queue).perform
        else
            job.delay.perform
        end
    end
  end

end