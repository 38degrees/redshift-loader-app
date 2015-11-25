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
    job.schedule
   
  end

  error_handler do |error|
    Airbrake.notify(error)
  end

end