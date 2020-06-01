class IncreaseLengthOfGoTermFields < ActiveRecord::Migration
  def change
  	change_column :scerevisiae_go_terms, :name, :string, limit: 250
  end
end
