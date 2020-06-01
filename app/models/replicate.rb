class Replicate < ActiveRecord::Base

	validates_presence_of :reps
	validates_uniqueness_of :reps, :message => "That replicate value already exists" 
	validates_numericality_of :reps

	def self.getRepPossibilities()
  	return Replicate.select('reps').map{|x| x.reps}
  end

end
