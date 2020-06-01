class AddLinks < ActiveRecord::Migration
  def change
  	remove_reference :experiment_comparer_colony_datasets, :experiment
  	remove_reference :experiment_query_colony_datasets, :experiment

  	add_reference :experiments, :experiment_comparer_colony_dataset
  	add_reference :experiments, :experiment_query_colony_dataset

  	add_index "experiments", ["experiment_comparer_colony_dataset_id"], name: "comparer_id_index", using: :btree
  	add_index "experiments", ["experiment_query_colony_dataset_id"], name: "query_id_index", using: :btree
  end
end
