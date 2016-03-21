class AddUpdatedAtStore < ActiveRecord::Migration

  def up
    change_table :tables do |t|
      t.datetime :max_updated_key
      t.datetime :reset_updated_key
      t.integer :max_primary_key
    end

    change_table :table_copies do |t|
      t.integer :table_id
    end
  end

end