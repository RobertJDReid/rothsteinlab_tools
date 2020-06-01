class AddIndexIForgotToAdd < ActiveRecord::Migration
  def change
  	add_index "experiment_colony_data", ["experiment_raw_dataset_id"]
  end
end
