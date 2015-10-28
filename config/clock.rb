require 'clockwork'
require 'clockwork/database_events'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'boot.rb'))

module Clockwork

  Clockwork.manager = DatabaseEvents::Manager.new

  sync_database_events model: ClockworkEvent, every: 1.minute do |clockwork_event|

    # Because job is cached we need to retrieve a fresh copy from DB to see if it is indeed still running
    job = ClockworkEvent.find(clockwork_event.id)
    if !job.running
        if job.queue
            job.delay(:queue => job.queue).perform
        else
            job.delay.perform
        end
    end
  end

end