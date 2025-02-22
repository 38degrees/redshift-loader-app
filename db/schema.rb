# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 12) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name"
    t.string "surname"
    t.string "email"
    t.string "crypted_password"
    t.string "role"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "clockwork_events", force: :cascade do |t|
    t.text "name"
    t.text "statement"
    t.integer "frequency"
    t.integer "runs"
    t.datetime "last_run_at"
    t.datetime "last_succeeded_at"
    t.text "at"
    t.text "error_message"
    t.text "queue"
    t.boolean "running"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "jobs", force: :cascade do |t|
    t.text "name"
    t.text "source_connection_string"
    t.text "destination_connection_string"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "table_copies", force: :cascade do |t|
    t.text "text"
    t.integer "rows_copied"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "table_id"
  end

  create_table "tables", force: :cascade do |t|
    t.integer "job_id"
    t.text "source_name"
    t.text "destination_name"
    t.text "primary_key"
    t.text "updated_key"
    t.boolean "insert_only"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "last_copied_at"
    t.datetime "max_updated_key"
    t.integer "max_primary_key"
    t.datetime "reset_updated_key"
    t.integer "time_travel_scan_back_period"
    t.boolean "delete_on_reset"
    t.text "copy_mode"
    t.boolean "disabled"
    t.boolean "run_as_separate_job"
    t.text "table_copy_type"
  end

end
