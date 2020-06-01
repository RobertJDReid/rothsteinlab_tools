class RenameDonorMatingType < ActiveRecord::Migration
  def change
  	rename_column :donors, :matingType, :mating_type
  end
end
