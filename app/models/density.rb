class Density < ActiveRecord::Base

	has_many :experiment_raw_datasets
	
	validates_presence_of :density
	validates_uniqueness_of :density, :message => " - That density already exists" 
	validates_numericality_of :density
	
	def self.getDensityPossibilities()
		return Density.select('density').map{|x| x.density}
  end

end
