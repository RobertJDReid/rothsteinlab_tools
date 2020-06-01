class ScerevisiaeGene < ActiveRecord::Base
	has_many :scerevisiae_hsapien_orthologs, :foreign_key => 'orf'
	
	def self.checkValidOrf(gene)
		# take is a bit faster than first as the sql is "Limit 1" as opposed to "order by [primary key] asc LIMIT 1"
		yGene =  ScerevisiaeGene.select('gene, orf').where("`gene` LIKE ?",gene).take
		yORF =  ScerevisiaeGene.select('gene, orf').where("`orf` LIKE ?",gene).take
		if(yGene)
			return {"orf"=>yGene.orf, "gene"=>yGene.gene}
		elsif(yORF)
			return {"gene"=>yORF.gene,"orf"=>yORF.orf}
		end
		return {"error"=>"Could not find yeast ORF/gene name."}
	end


end
