class AddDrosophiliaInteractions < ActiveRecord::Migration
  def change
  	create_table(:dmelanogaster_droidb_interactions, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8')  do |t|
  	  t.string :flyID_a, limit: 12, index: true, null:false
  	  t.string :flyID_b, limit: 12, index: true, null:false
  	  t.string :symbol_a, limit: 40, index: true
  	  t.string :symbol_b, limit: 40, index: true
  	  t.text :url
  	  t.string :interaction_category, limit: 20, index:true
  	  t.string :interaction_type, limit: 100, index: true
  	  t.decimal :score, precision: 15, scale: 5
  	  t.timestamps
  	end
  	# this command ('set_table_comment') is available thanks to the migration_comments gem
  	set_table_comment :dmelanogaster_droidb_interactions, 'Interactions curated by the Drosophila Interactions Database (DroID) -- http://www.droidb.org/DBdescription.jsp.'
    add_index "dmelanogaster_droidb_interactions", ["symbol_a", "symbol_b", "interaction_type"], name: "uniques", unique: true
    add_index "dmelanogaster_droidb_interactions", ["flyID_b"], name: "flyA", using: :btree
    add_index "dmelanogaster_droidb_interactions", ["flyID_a"], name: "flyB", using: :btree
    add_index "dmelanogaster_droidb_interactions", ["interaction_type"], name: "drosophilia_i_type", using: :btree
    add_index "dmelanogaster_droidb_interactions", ["interaction_category"], name: "drosophilia_i_category", using: :btree
  end
end
