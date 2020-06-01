class AddExperimentFields < ActiveRecord::Migration
  def change
  	add_column("experiments", "pre_screen_library_replicates", :integer, :limit=>1, :null=>true)
  	add_column("experiments", "mating_time", :integer, :limit=>2, :null=>true)
  	add_column("experiments", "first_gal_leu_time", :integer, :limit=>2, :null=>true)
  	add_column("experiments", "second_gal_leu_time", :integer, :limit=>2, :null=>true)
  	add_column("experiments", "final_incubation_time", :integer, :limit=>2, :null=>true)
  end
end
