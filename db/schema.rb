# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 6) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: true do |t|
    t.string   "name"
    t.string   "surname"
    t.string   "email"
    t.string   "crypted_password"
    t.string   "role"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "clockwork_events", force: true do |t|
    t.text     "name"
    t.text     "statement"
    t.integer  "frequency"
    t.integer  "runs"
    t.datetime "last_run_at"
    t.datetime "last_succeeded_at"
    t.text     "at"
    t.text     "error_message"
    t.text     "queue"
    t.boolean  "running"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delayed_jobs", force: true do |t|
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

  create_table "jobs", force: true do |t|
    t.text     "name"
    t.text     "source_connection_string"
    t.text     "destination_connection_string"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "table_copies", force: true do |t|
    t.text     "text"
    t.integer  "rows_copied"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tables", force: true do |t|
    t.integer  "job_id"
    t.text     "source_name"
    t.text     "destination_name"
    t.text     "primary_key"
    t.text     "updated_key"
    t.boolean  "insert_only"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "last_copied_at"
    t.datetime "max_updated_at_key"
  end

end
