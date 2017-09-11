class AddCopyMode < ActiveRecord::Migration

  def change
    change_table :tables do |t|
      t.text :copy_mode
    end
  end

end
