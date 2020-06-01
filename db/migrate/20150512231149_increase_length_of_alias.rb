class IncreaseLengthOfAlias < ActiveRecord::Migration
  def change
  	change_column :scerevisiae_genes, :alias, :string, limit: 200
  end
end