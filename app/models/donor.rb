class Donor < ActiveRecord::Base
	belongs_to :user, :foreign_key => "created_by"

	validates_inclusion_of :created_by, :in => User.select('login').where("`permissions` IN ('admin','labMember')").map { |e| e.login  }
	validates_inclusion_of :updated_by, :in => User.select('login').where("`permissions` IN ('admin','labMember')").map { |e| e.login  }
	validates_presence_of  :wNumber
	validates_presence_of  :mating_type

	def number_and_type
		@number_and_type = wNumber+' - '+mating_type
	end

end
