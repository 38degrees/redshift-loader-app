class AddDelayedJobs < ActiveRecord::Migration
      def up
          create_table :delayed_jobs do |t|
            t.integer  "priority",   default: 0
            t.integer  "attempts",   default: 0
            t.text     "handler"
            t.text     "last_error"
            t.datetime "run_at"
            t.datetime "locked_at"
            t.datetime "failed_at"
            t.string   "locked_by"
            t.string   "queue"
            t.datetime "created_at"
            t.datetime "updated_at"
          end
    end
end