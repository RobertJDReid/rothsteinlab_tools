class RemoveColumnsFromExcludedColonies < ActiveRecord::Migration
  def change
  	# remove_index("excluded_colonies", name: "index_excluded_colonies_on_experiment_id")
  	remove_column :excluded_colonies, :experiment_id
  	remove_column :excluded_colonies, :created_at
  	remove_column :excluded_colonies, :updated_at
  	add_index "excluded_colonies", ["plate"]
  	add_index "excluded_colonies", ["row"]
  	add_index "excluded_colonies", ["column"]
  end
end
