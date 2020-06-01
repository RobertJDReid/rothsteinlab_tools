class IncreaseGoColumnLengths < ActiveRecord::Migration
  def change
  	change_column :scerevisiae_go_process_associations, :withOrFrom, :string, limit: 400
  	change_column :scerevisiae_go_process_associations, :objectName, :string, limit: 100
  	change_column :scerevisiae_go_process_associations, :dbReference, :string, limit: 400
  	change_column :scerevisiae_go_process_associations, :evidence, :string, limit: 20
  	change_column :scerevisiae_go_process_associations, :assignedBy, :string, limit: 50
  end
end
