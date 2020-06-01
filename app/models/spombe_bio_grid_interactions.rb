class SpombeBioGridInteractions < ActiveRecord::Base
	self.table_name = "spombe_bioGrid_interactions"
	
	validates_presence_of :intA,:intB,:throughput,:expSystemType,:expSystem,:pubmedID 

	def self.getInteractions(genes,interactionTypes)
		interactions = []
		nodes = []
		if(!interactionTypes || interactionTypes.length<1)
			for index in 0..genes.size
				nodes << {"id"=>genes[index], "name"=>genes[index]}
			end
		else		
			# iterate over the genes, find all relavent interaction
			for index in 0..(genes.size-1)
				nodes << {"id"=>genes[index], "name"=>genes[index]}

				interactions = interactions + SpombeBioGridInteractions.where("`intA` = ? AND `intB` IN (?) AND `expSystem` IN (?)",genes[index],genes,interactionTypes).select('intA, intB, expSystem')
				interactions = interactions + SpombeBioGridInteractions.where("`intB` = ? AND `intA` IN (?) AND `expSystem` IN (?)",genes[index],genes,interactionTypes).select('intA, intB, expSystem')
			end		
		end
		return {"edges" => interactions.map { |e| {"source"=>e.intA,"target"=>e.intB,"iType"=>e.expSystem}  }, "nodes"=> nodes}
	end

end