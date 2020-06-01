class ScerevisiaeGoProcessAssociations < ActiveRecord::Base

	def self.getSignificantGOmembership(genes,pValueThreshold=0.05)
		require 'hypergeo_stats'
		hyp =  HStats::HypergeoStats.new
		if(!genes || genes.length<1)
			return {}
		end

		data = ScerevisiaeGoProcessAssociations.select('`ORF`, `go_id`').where("`ORF` IN (?)",genes)

		# initialize a hash of hashes with count and orf fields initialized
		memberships = Hash.new{ |h, k| h[k] = {"count"=>0,"orfs"=>[]} }
		data.each do |go|
			memberships[go.go_id]["count"] += 1
			memberships[go.go_id]["orfs"] << go.ORF
		end
		data = nil

		# intialize an array
		significantGoTerms=[]

		tp = genes.length
		t = 6000
		memberships.each_key do |go_id|
			data = ScerevisiaeGoTerms.select('`size`, `name`, `definition`').where("`go_id` = ?",go_id).limit(1)[0]
			logger.debug(data.inspect)
			# gp == memberships[go_id]["count"]
			# tg == data.size
			# tp == genes.length
			# t = 6000
			pVal = hyp.cum_hyperg_pval_info(memberships[go_id]["count"],data.size,tp,t)
			if(pVal[0] < pValueThreshold && pVal[0]>0) # we only care about over-representation
				# if(pVal[0].abs < 0.001)
				# 	pVal[0] = "%.3E" % pVal[0]
				# else
				# 	pVal[0] = "%.3g" % pVal[0]
				# end
				significantGoTerms << {"id" => go_id, "name" => data.name, "definition" => data.definition, "p-value"=>pVal[0],"genes"=> memberships[go_id]["orfs"]}
			end
		end
		
		return significantGoTerms.sort_by { |hsh| hsh["p-value"] }
	end

	def self.getGOidInfo(term)
		if(term.length > 100)
			return false
		end
		# find all orfs associated with this go id
		
		data = ScerevisiaeGoProcessAssociations.where("`go_id` LIKE ?",term).select('ORF, go_id')
		if data.length > 0
			goTermName = ScerevisiaeGoTerms.where("`go_id` = ?",term).select('go_id, name')
			goNameLookup={}
			goTermName.each do |row|
				goNameLookup[row.go_id]=row.name
			end

			members = Hash.new{ |h, k| h[k] = [] }
			data.each do |row|
				members["#{goNameLookup[row.go_id]} (#{row.go_id})"] << row.ORF
			end
			return members.map{|a,b| {"term"=>a, "genes"=> b}}
		end
		return []
	end
	
	def self.goTermLookUp(term)
		if(term.length > 100)
			return false
		end
		terms = ScerevisiaeGoTerms.select('go_id, name').where("`name` LIKE ?","%#{term}%")
		if (terms.length > 0)
			members = Hash.new{ |h, k| h[k] = [] }
			terms.each do |term|
				# find all orfs associated with this go id
				data = ScerevisiaeGoProcessAssociations.select('ORF, go_id').where("`go_id` = ?",term.go_id)
				data.each do |row|
					members["#{term.name} (#{term.go_id})"] << row.ORF
				end
			end
			return members.map{|a,b| {"term"=>a, "genes"=> b}}
		end
		return []
	end

end