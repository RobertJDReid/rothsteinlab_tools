class AddIndex < ActiveRecord::Migration
  def change
  	add_index "experiments", ["experiment_raw_dataset_id"], name: "log_dataset_id_index", using: :btree
  end
end
