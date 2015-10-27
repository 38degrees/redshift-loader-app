require 'clockwork'
require 'clockwork/database_events'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'boot.rb'))

module Clockwork

  Clockwork.manager = DatabaseEvents::Manager.new

  sync_database_events model: ClockworkEvent, every: 1.minute do |job|
    if !job.running
        if job.queue
            job.delay(:queue => job.queue).perform
        else
            job.delay.perform
        end
    end
  end

end