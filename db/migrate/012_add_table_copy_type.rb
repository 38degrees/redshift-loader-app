class AddTableCopyType < ActiveRecord::Migration

  def change
    change_table :tables do |t|
      t.text :table_copy_type
    end
  end

end
