class AddRowsAndColsToDensity < ActiveRecord::Migration
  def change
  	# :limit	Numeric Type	Column Size	Max value
  	# 1	tinyint	1 byte	127
  	# 2	smallint	2 bytes	32767
  	# 3	mediumint	3 byte	8388607
  	# nil, 4, 11	int(11)	4 byte	2147483647
  	# 5..8	bigint	8 byte	9223372036854775807

  	add_column("densities", "rows", :integer, :limit=>2, :null=>false, :default=>1)
  	add_column("densities", "columns", :integer, :limit => 2, :null=>false, :default=>1)
  end
end
