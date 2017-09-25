class AddRunAsSeparateJob < ActiveRecord::Migration

  def change
    change_table :tables do |t|
      t.boolean :run_as_separate_job
    end
  end

end
