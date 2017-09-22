class ClockworkEvent < ActiveRecord::Base

    validates_presence_of :frequency, :name, :statement

    def self.admin_fields
      {
        name: :text,
        statement: :text_area,
        frequency: :text,
        at: :text,
        queue: :text,
        runs: {:type => :text, :edit => false},
        last_run_at: {:type => :text, :edit => false},
        last_succeeded_at: {:type => :text, :edit => false},
        error_message: {:type => :text, :edit => false},
        running: {:type => :check_box, :edit => false}
      }
    end
    
    # Don't run if we last succeeded within frequency seconds
    #NOTE: This shouldn't be necessary, but is due to Clockwork bug... See long comment in config/clock.rb
    def if?(time)
        return true if !last_succeeded_at.present?
        
        time_since_last_success = (time - last_succeeded_at.to_datetime)
        if  time_since_last_success >= frequency.to_i.seconds
            logger.debug "It's been #{time_since_last_success} since last success of #{self.id} - #{self.name}, frequency is #{frequency} s, triggering job"
            return true
        else
            logger.debug "It's been #{time_since_last_success} since last success of #{self.id} - #{self.name}, frequency is #{frequency} s, NOT triggering job"
            return false
        end
    end

    def schedule
      if running && (DateTime.now - last_run_at.to_datetime) * 1.day > 61.seconds
        update_attribute(:running, false)
        logger.info "ClockworkEvent '#{name}' stuck in running state - resetting..."
      end

      if !running
        ClockworkEventWorker.perform_async(self.id)
      end
    end

    def perform
        reload
        if !running
          update_attribute(:running, true)
          update_attribute(:last_run_at, DateTime.now)    
          update_attribute(:runs, (runs || 0) + 1)

          check_thread = Thread.new do
            loop do
              sleep 60
              update_attribute(:last_run_at, DateTime.now)
              puts "#{self.name} checking in..."
            end
          end

          begin
            eval(statement) 
            update_attribute(:last_succeeded_at, DateTime.now)
            update_attribute(:error_message, nil)
          rescue Exception => e
            update_attribute(:error_message, e.message)
            raise e
          ensure
            update_attribute(:running, false)
            check_thread.exit            
          end  
                  
        end        
    end

    def self.clear_running_jobs
      ClockworkEvent.update_all(running: false)
    end

end
