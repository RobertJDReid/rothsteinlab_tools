class CreateExperimentComparerColonyDatasets < ActiveRecord::Migration
  def change
    create_table :experiment_comparer_colony_datasets do |t|
      t.references :experiment, index: true
      t.references :density, index: true
      t.references :pwj_plasmid, index: true
      t.string :condition, limit: 50
      t.integer :number_of_plates, limit: 4
      t.date :batch_date
      t.string :updated_by, limit: 50
      t.timestamps
    end
  end
end
