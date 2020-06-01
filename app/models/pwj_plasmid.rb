class PwjPlasmid < ActiveRecord::Base
	has_many :experiment_raw_datasets
	

	validates_presence_of  :number,:promoter, :yeast_selection, :bacterial_selection, :gene, :parent 
	validates_length_of :number, :within => 6..9, :message => "The plasmid number is too short. Be sure to preceed it with 'pWJ'." 
	validates_length_of :promoter, :within => 3..7
	validates_uniqueness_of :number, :message => "That plasimd already exists" 
	validates_format_of :number, :with => /\Apwj[0-9]{3,6}\z/i, :message => "The plasmid number was not entered correctly. It must be 'pWJ' followed by 3-6 integers."
	# validates_format_of :parent, :with => /\Apwj[0-9]{3,6}\z/i, :message => "The parent number was not entered correctly. It must be 'pWJ' followed by 3-6 integers."

	def pwj_details
		@pwj_details = number+' - '+promoter+' - '+gene
	end
	
	def self.validateQuery(query, promoter)
		if(promoter =~ /gal/i)
			promoter = "GAL"
		elsif(promoter =~ /Cu$/i)
			promoter = "CUP"
		end
		if(!query || query.length < 2)	
			return "Invalid query: '#{query}'"
		end
		p=PwjPlasmid.where("number = ? AND promoter = ?", query, promoter).select("id, number, promoter, yeast_selection, gene, parent")		
		if(p.nil? || p.length < 1)
			p=PwjPlasmid.where(" gene= ? AND promoter = ?", query, promoter).select("id, number, promoter, yeast_selection, gene, parent")	
			if(p.nil? || p.length < 1)
				p=PwjPlasmid.where("number = ?", query).select("id, number, promoter, yeast_selection, gene, parent")
				if(p.nil? || p.length < 1)
					p=PwjPlasmid.where("gene= ?", query).select("id, number, promoter, yeast_selection, gene, parent")	
					if(p.nil? || p.length < 1)
						p=PwjPlasmid.where("number LIKE ?", "%#{query}%").select("id, number, promoter, yeast_selection, gene, parent")	
						if(p.nil? || p.length < 1)
							p=PwjPlasmid.where("gene LIKE ?", "%#{query}%").select("id, number, promoter, yeast_selection, gene, parent")	
							if(p.nil? || p.length < 1)
								return "Not found!"
							end
						end
		    	end
	    	end
    	end
  	end
  	p = p.to_a.map(&:serializable_hash)
  	p.each_with_index {|val, index|
			p[index]['parentExists'] = 0
			if(PwjPlasmid.exists?(["number LIKE ?", p[index]['parent']])) 
				p[index]['parentExists'] = 1
			end
		}

   	return p
   	
	end
end