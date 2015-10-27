class AddClockworkEvents < ActiveRecord::Migration

    def up

        create_table :clockwork_events do |t|
            t.text :name
            t.text :statement
            t.integer :frequency #seconds
            t.integer :runs
            t.timestamp :last_run_at
            t.timestamp :last_succeeded_at
            t.text :at
            t.text :error_message
            t.text :queue
            t.boolean :running
            t.timestamps
        end

    end

end