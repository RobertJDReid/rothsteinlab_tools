class ScreenResult < ActiveRecord::Base

	def self.findScreenResults(gene)
		return ScreenResult.where("`ORF` = ?",gene)
	end

end