class SwitchTableColumns < ActiveRecord::Migration
  def change
  	remove_index("experiments", name: "log_dataset_id_index")
  	remove_reference :experiments, :experiment_raw_dataset


  	add_reference :experiments, :experiment_comparer_raw_dataset
  	add_reference :experiments, :experiment_query_raw_dataset

  	add_index "experiments", ["experiment_comparer_raw_dataset_id"], name: "comparer_dataset_id_index", using: :btree
  	add_index "experiments", ["experiment_query_raw_dataset_id"], name: "query_dataset_id_index", using: :btree

  	remove_reference :experiment_colony_data, :experiment_comparer_colony_dataset
  	remove_reference :experiment_colony_data, :experiment_query_colony_dataset

  	add_reference :experiment_colony_data, :experiment_raw_dataset

  end
end
