class StrainLibrary < ActiveRecord::Base

	validates_uniqueness_of :name, :message => "That strain library value already exists" 
	validates_presence_of  :selectable_marker, :key_file_location, :background,:name, :mating_type
	validates_length_of    :name,  :within  =>  5..100
	validates_length_of    :selectable_marker,  :within  =>  3..20
	validates_length_of    :key_file_location,  :within  =>  7..200
	validates_inclusion_of :mating_type, :in => ["a", "alpha", "diploid"]
	validates_format_of :key_file_location, :with => URI::regexp(%w(http https))
	# attr_protected :default # this makes sure users cannot set them by sending a post request - you have to update them in the model

end
