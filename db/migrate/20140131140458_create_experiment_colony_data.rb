class CreateExperimentColonyData < ActiveRecord::Migration
  def change
    create_table :experiment_colony_data do |t|
      t.references :experiment_comparer_colony_dataset
      t.references :experiment_query_colony_dataset
      t.string :plate, limit: 50, index: true
      t.string :row, limit: 5, index: true
      t.integer :column, limit: 5, index: true
      t.decimal :colony_measurement, precision: 15, scale: 5
      t.decimal :colony_circularity, precision: 15, scale: 5
      t.timestamps
    end

    add_index "experiment_colony_data", ["experiment_comparer_colony_dataset_id"], name: "comparer_id_index", using: :btree
    add_index "experiment_colony_data", ["experiment_query_colony_dataset_id"], name: "query_id_index", using: :btree
  end
end
