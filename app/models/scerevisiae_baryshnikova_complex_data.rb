class ScerevisiaeBaryshnikovaComplexData < ActiveRecord::Base
	self.table_name = "scerevisiae_baryshnikova_complex_data"

	def self.complexTermLookUp(term)
		if(term.length > 100)
			return false
		end
		data = ScerevisiaeBaryshnikovaComplexData.select('ORF, complex').where("`complex` LIKE ?","%#{term}%")
		members = Hash.new{ |h, k| h[k] = [] }
		data.each do |row|
			members[row.complex] << row.ORF
		end
		return members.map{|a,b| {"term"=>a, "genes"=> b}}
	end
end