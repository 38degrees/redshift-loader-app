class AddTimeTravelRewind < ActiveRecord::Migration

  def up
    change_table :tables do |t|
      t.integer :time_travel_scan_back_period
    end
  end

end