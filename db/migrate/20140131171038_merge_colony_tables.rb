class MergeColonyTables < ActiveRecord::Migration
  def change

  	remove_reference :experiments, :experiment_comparer_colony_dataset
  	remove_reference :experiments, :experiment_query_colony_dataset

  	# removing the reference (and the column) has the effect of also removing any indices on the column, so the
  	# below statements are not necessary, and in fact, will cause this migration to fail.
  	# remove_index "experiments", ["experiment_comparer_colony_dataset_id"]
  	# remove_index "experiments", ["experiment_query_colony_dataset_id"]

  	drop_table :experiment_comparer_colony_datasets

  	rename_table('experiment_query_colony_datasets', 'experiment_raw_datasets')

  	add_reference :experiments, :experiment_raw_dataset

  end
end
