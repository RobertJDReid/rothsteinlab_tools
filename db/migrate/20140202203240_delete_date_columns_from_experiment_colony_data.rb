class DeleteDateColumnsFromExperimentColonyData < ActiveRecord::Migration
  def change
  	remove_column :experiment_colony_data, :created_at
  	remove_column :experiment_colony_data, :updated_at
  end
end
