class ExperimentDateRenameToBatchDate < ActiveRecord::Migration
  def change
  	rename_column :experiments, :date, :batch_date
  end
end
