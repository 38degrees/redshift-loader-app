class AddDisabled < ActiveRecord::Migration

  def change
    change_table :tables do |t|
      t.boolean :disabled
    end
  end

end
