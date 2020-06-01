class ChangeColumnLengths < ActiveRecord::Migration
  def change
  	change_column :spombe_bioGrid_interactions, :intA, :string, limit: 40
  	change_column :spombe_bioGrid_interactions, :intB, :string, limit: 40
  	change_column :spombe_bioGrid_interactions, :throughput, :string, limit: 40

  	change_column :scerevisiae_bioGrid_interactions, :intA, :string, limit: 40
  	change_column :scerevisiae_bioGrid_interactions, :intB, :string, limit: 40
  	change_column :scerevisiae_bioGrid_interactions, :throughput, :string, limit: 40

  	change_column :hsapien_bioGrid_interactions, :intA, :string, limit: 40
  	change_column :hsapien_bioGrid_interactions, :intB, :string, limit: 40
  	change_column :hsapien_bioGrid_interactions, :throughput, :string, limit: 40
  end
end
