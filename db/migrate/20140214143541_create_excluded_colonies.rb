class CreateExcludedColonies < ActiveRecord::Migration
  def change
    create_table :excluded_colonies do |t|
      t.references :experiment, index: true
      t.references :experiment_raw_dataset, index: true
      t.string :plate, limit: 50, index: true
      t.string :row, limit: 5
      t.integer :column, limit: 5
      t.timestamps
    end
  end
end
