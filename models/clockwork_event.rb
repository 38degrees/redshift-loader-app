class ClockworkEvent < ActiveRecord::Base
  validates_presence_of :frequency, :name, :statement

  def self.admin_fields
    {
      id: { type: :number, edit: false },
      name: :text,
      statement: :text_area,
      frequency: :text,
      at: :text,
      queue: :text,
      runs: { type: :text, edit: false },
      last_run_at: { type: :text, edit: false },
      last_succeeded_at: { type: :text, edit: false },
      error_message: { type: :text, edit: false },
      running: { type: :check_box, edit: false }
    }
  end

  def schedule
    if running && (DateTime.now - last_run_at.to_datetime) * 1.day > 61.seconds
      update_attribute(:running, false)
      logger.info "ClockworkEvent '#{name}' stuck in running state - resetting..."
    end

    ClockworkEventWorker.perform_async(id) unless running
  end

  def perform
    reload
    return if running

    update_attribute(:running, true)
    update_attribute(:last_run_at, DateTime.now)
    update_attribute(:runs, (runs || 0) + 1)

    check_thread = Thread.new do
      loop do
        sleep 60
        update_attribute(:last_run_at, DateTime.now)
        puts "#{name} checking in..."
      end
    end

    begin
      eval(statement)
      update_attribute(:last_succeeded_at, DateTime.now)
      update_attribute(:error_message, nil)
    rescue StandardError => e
      update_attribute(:error_message, e.message)
      raise e
    ensure
      update_attribute(:running, false)
      check_thread.exit
    end
  end

  def self.clear_running_jobs
    ClockworkEvent.update_all(running: false)
  end
end
