class App < ActiveRecord::Base
	require 'json'

	# for CLIK
	def self.getInteractionTypes(params = {})
		organism = params[:organism] || "Scerevisiae"
		database = params[:db] || "BioGRID"
		interactions = Hash.new
		begin
			if(SupportedOrganisms.exists?(["organism LIKE ?", organism]))
				interactionFile = File.open("#{Rails.root}/public/cgi-bin/interactionData/#{database}/#{organism.downcase}_interactionTypes.txt", "r")
				while (line = interactionFile.gets)
					temp = line.split(/\:/)
					temp[0]=temp[0].titleize.strip
					temp[1]=temp[1].strip
					interactions[temp[0]] ||= []
					interactions[temp[0]] << temp[1]
				end
				interactionFile.close
			else
				interactions[:error] = "<em>#{organism.capitalize}</em> interaction data is not supported."
			end
		rescue => err
			subject = "Could not load <em>#{organism.capitalize}</em> interactions."
			msg     = "path = #{Rails.root}/public/cgi-bin/interactionData/#{database}/#{organism.downcase}_interactionTypes.txt\n\nerr:\n#{err}"
			ErrorMailer.error_mail('admin@rothsteinlab.com', subject, msg).deliver
			interactions[:error] = subject
		end
		return interactions
	end

	# for clik
	def self.getBioGridVersion()
		begin
			version = ''
			File.open("#{Rails.root}/public/cgi-bin/interactionData/BioGRID/biogrid_versionNumber.txt", "r"){|f| version = f.readline}
			return version
		rescue
			return 'n/a'
		end
	end

	def self.getDroID_version()
		d_id = SupportedOrganisms.select('biogrid_version').where(["organism LIKE ?", 'Dmelanogaster'])
		return d_id[0].biogrid_version
	end

	def self.findGOtermOrComplex(term)
		# if this is a go term id then look it up
		if(term =~ /\AGO\:/i)
			if(term.gsub(/\AGO\:/i,"") =~ /\A[0-9]{7}\z/)
				return {"GO" => ScerevisiaeGoProcessAssociations.getGOidInfo(term)}
			else
				return {"error"=>"Bad GO id entered"}
			end
		# else try to find other stuff
		else
			data1 = ScerevisiaeGoProcessAssociations.goTermLookUp(term)
			data2 = ScerevisiaeBaryshnikovaComplexData.complexTermLookUp(term)
			return {"GO"=>data1, "COMPLEX"=>data2}
		end
		return {"error"=>"Nothing found"}
	end

	# for data intersection tool
	def self.getDatasetOverlaps(params)
		datasets = Array.new
		# iterate over datasets, split each dataset based on new line characters, then split each individual
		# dataset into an array based on spaces, commas or |
		params[:area1].upcase.split(/\r|\n|\r\n/).compact.delete_if{|x| x == "" }.each do |dataset|
			datasets << dataset.split(/\r|,|\n|,\s+|\s+|\|/).compact.delete_if{|x| x == "" }
		end
		comparisons=Hash.new
		overLapCount=Hash.new

		ids = datasets.flatten
		uniques = ids.uniq
		uniques = Hash[*uniques.collect { |v|	[v, 1]	}.flatten]

		i=0
		params[:datasetID] ||= {}

		uniqs = Hash.new
		# iterate over array of arrays
		datasets.each do |dataset|
			dataset.uniq! # remove duplicates in array
			params[:datasetID].each_pair do |num, dataLabel| # iterate over dataset labels
				n=num.to_i # convert num to integer value
				# if the dataset we are iterating over is not itself AND we have not made a comparison, then
				# find the intersection of the 2 screens
				if(n!=i && !comparisons.has_key?("'#{dataLabel}' to '#{params[:datasetID][i.to_s]}'"))
					comparisons["'#{params[:datasetID][i.to_s]}' to '#{dataLabel}'"]=(dataset & datasets[n])
				end
			end
			uniqs[params[:datasetID][i.to_s]]=[]
			dataset.each do |guy|
				if(uniques.has_key?(guy))
					uniques[guy] = params[:datasetID][i.to_s]
					if(overLapCount.has_key?(guy))
						uniques.delete(guy)
					end
				end
				overLapCount["#{guy}"] ||= []
			 # puts params[:datasetID][i.to_s]
				overLapCount["#{guy}"] << "#{params[:datasetID][i.to_s]}"
			end
			i+=1
		end

		# logger.debug { uniques.inspect }
		uniques.each_pair do |id, setName|
			if(overLapCount.has_key?(id))
				overLapCount.delete(id)
			end
			uniqs[setName] << id
		end
		# logger.debug { uniqs.inspect }

		return comparisons, overLapCount, uniqs
	end

	def self.parameterize(params)
		URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))
	end


	def self.checkValidGenes(params, getEnsembl=true)
		# convert genes in params array to upcase -- find all genes in DB that match exactly
		badGenes=[]
		goodGenes={}
		if(!params[:genes] || params[:genes].length < 1 || !params[:organism])
			return {'goodGenes'=>goodGenes, 'badGenes'=>badGenes}
		end
		if(params[:genes].class == String)
			params[:genes]=params[:genes].split(',')
		end
		params[:genes].map!(&:upcase)
		params[:organism].upcase!
		badGenes = params[:genes]
		if(params[:organism] == 'HUMAN')
			hGenes =  HsapienEnsemblGene.where("`geneName` IN (?)",params[:genes]).select('geneName, ensemblID').order('geneName')
			if(getEnsembl)
				hGenes.each do |x|
					badGenes = badGenes - [x.geneName]
					goodGenes[x.ensemblID]=x.geneName
				end
			else
				hGenes.each do |x|
					badGenes = badGenes - [x.geneName]
					goodGenes[x.geneName]=1
				end
			end
		else
			yGenes = ScerevisiaeGene.where("`gene` IN (?)",params[:genes]).select('gene, orf').order('gene')
			yORFs = ScerevisiaeGene.where("`orf` IN (?)",params[:genes]).select('gene, orf')
			yGenes.each do |x|
				badGenes = badGenes - [x.gene]
				goodGenes[x.orf]=x.gene
			end
			yORFs.each do |x|
				badGenes = badGenes - [x.orf]
				goodGenes[x.orf]=x.gene
			end
		end
		goodGenes["_size"]=goodGenes.length
		return {'goodGenes'=>goodGenes, 'badGenes'=>badGenes.uniq}
	end

	def self.checkForHumanOrthologs(genes = {})
		# logger.debug("genes = #{genes.inspect} #{genes.keys}")
		badGenes=[]
		goodGenes=[]
		if(! genes.methods.include? :keys)
			return nil
		end

		goodGenes = ScerevisiaeHsapienOrtholog.where("`yeastOrf` IN (?)",genes.keys).select('yeastOrf, humanGeneName, humanEnsemblID')
		goodGenes = goodGenes.map{|x|
			{"gene"=>x.humanGeneName.upcase, "id"=>x.humanEnsemblID.upcase, "orf"=>x.yeastOrf.upcase, "yGene"=>genes[x.yeastOrf.upcase]}
		}
		return goodGenes
	end

end