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

    def perform
        if !running
          update_attribute(:running, true)
          update_attribute(:last_run_at, Time.now)    
          update_attribute(:runs, (runs || 0) + 1)
          begin
            eval(statement) 
            update_attribute(:last_succeeded_at, Time.now)
            update_attribute(:error_message, nil)
          rescue Exception => e
            update_attribute(:error_message, e.message)
            raise e
          ensure
            update_attribute(:running, false)
          end          
        end        
    end

    def self.clear_running_jobs
      ClockworkEvent.update_all(running: false)
    end

end