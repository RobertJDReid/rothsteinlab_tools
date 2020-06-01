class AddMoreIndices < ActiveRecord::Migration
  def change
  	add_index "experiment_colony_data", ["plate"]
  	add_index "experiment_colony_data", ["row"]
  	add_index "experiment_colony_data", ["column"]
  end
end
