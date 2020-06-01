class AddKeyFileShortName < ActiveRecord::Migration
  def change
  	add_column("strain_libraries", "short_name", :string, :limit=>15)
  end
end
