class AddChangesToCopy < ActiveRecord::Migration

    def up
        change_table :tables do |t|
            t.timestamp :last_copied_at
        end

        create_table :table_copies do |t|
            t.text :text
            t.integer :rows_copied
            t.timestamp :started_at
            t.timestamp :finished_at
            t.timestamps
        end
    end

end