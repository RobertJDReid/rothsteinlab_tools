class AddCommentsField < ActiveRecord::Migration
  def change
  	add_column :experiment_raw_datasets, :comments, :text
  end
end
