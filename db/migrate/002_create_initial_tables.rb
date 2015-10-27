class CreateInitialTables < ActiveRecord::Migration
  def self.up
    create_table :tables do |t|
      t.integer :job_id
      t.text :source_name
      t.text :destination_name
      t.text :primary_key
      t.text :updated_key
      t.boolean :insert_only
      t.timestamps
    end

    create_table :jobs do |t|
      t.text :name
      t.text :source_connection_string
      t.text :destination_connection_string
      t.timestamps
    end
  end

  def self.down
    
  end
end
