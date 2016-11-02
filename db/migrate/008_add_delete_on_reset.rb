class AddDeleteOnReset < ActiveRecord::Migration

  def up
    change_table :tables do |t|
      t.boolean :delete_on_reset
    end
  end

end