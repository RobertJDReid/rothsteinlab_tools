class Cbio < ActiveRecord::Base
	require 'csv'
	require 'rubygems'
	require 'net/http'

	def self.getCbioScores(params)
		fieldErrors={}
		# check to make sure all fields are defined
		["cancerStudy", "genes", "cancerAlteration", "zThresh", "CNV_thresh", "cancerCaseList"].each do |field| # "pValuesToConsider",
			if(!params[field])
				msg = field
				if(field =~ /cancerStudy/)
					msg = "Cancer Study"
				elsif(field =~ /zthresh/)
					msg = "Z-Score Threshold"
				elsif (field =~ /CNV_thresh/)
					msg = "CNV Threshold"
				elsif (field =~ /cancerAlteration/)
					msg = "Alteration Type"
				elsif (field =~ /cancerCaseList/)
					msg = "Case Type"
				end
				fieldErrors[field]="Could not find a value for the '#{msg}' field."
			end
		end
		return {"error" => fieldErrors } if(fieldErrors.length > 0)
		# if defined but not a number, then...
		if(!params[:zThresh].numeric?)
			 fieldErrors["zThresh"]="'#{params[:zThresh]}' is not a valid 'Z-Score' value."
		end
		if(!params[:CNV_thresh].numeric?)
			 fieldErrors["CNV_thresh"]="'#{params[:CNV_thresh]}' is not a valid 'CNV Threshold' value."
		end
		return {"error" => fieldErrors } if(fieldErrors.length > 0)

		params[:genes]=params[:genes].split(/\r|,|\n|,\s+|\s+|\|/).compact.delete_if{|x| x == "" }
		if(params[:genes].length<=1)
			params[:genes] = App.checkValidGenes({:genes=>params[:genes], :organism=>"human"})

			params[:genes][:goodGenes].delete("_size") if params[:genes][:goodGenes].has_key?("_size");
			params[:genes][:goodGenes]=params[:genes][:goodGenes].map{|key,val|{"gene"=>val}}
		else
			# create a hash in params[:genes][:goodGenes]. Since we do not have ensembl ids,
			# the gene names serve as the keys and values are nil
			temp=params[:genes].map{|val| {"gene"=>val}}
			params[:genes]={}
			params[:genes][:goodGenes]=temp
			params[:genes][:badGenes]=[]
		end

		if(params[:genes][:goodGenes].length < 1)
			fieldErrors["genes"] =  "0 valid genes found."
		end
		return {"error" => fieldErrors } if(fieldErrors.length > 0)

		genesToQuery = {"genes"=>params[:genes][:goodGenes]}

		badData = {}# ??

		caseListId = {"good" => params[:cancerCaseList]}
		caseListId ||= getCaseList(params[:cancerStudy], {:max => true})
		return caseListId if(caseListId.has_key?("error"))

		boundry = nil
		# if we can id this data as CNA or mRNA z-scores, then...
		if(params[:cancerAlteration] =~ /gistic/i)
			boundry = params[:CNV_thresh].to_f
		elsif(params[:cancerAlteration] =~ /z/i)
			boundry = params[:zThresh].to_f
		else
			fieldErrors["cancerAlteration"] = "ERROR! I don't know how to process #{params[:cancerAlteration]} data!"
			return {"error" => fieldErrors }
		end
		negBoundry = boundry * -1.0

		table = "<table id='scoreTable'><thead>"
		#table << "<th>Cancer Study</th><th>Alteration Type</th>"
		table << "<th>Gene</th><th>Total Tumors</th>"
		table << "<th># up</th><th>%</th><th>Mean of Up</th><th># down</th><th>%</th><th>Mean of Down</th><th>Overall Mean</th></thead>"
		#allData = Hash.new(&(p=lambda{|h,k| h[k] = Hash.new(&p)}))
		allData = h = Hash.new { |h, k| h[k] = Hash.new{ |h, k| h[k] = Hash.new{ |h, k| h[k] = 0 } } }
		#puts genesToQuery.inspect
		summarizeProfileData({:genetic_profile_id=>[params[:cancerAlteration]], :typeOfAlteration=>"whoCares"}, caseListId["good"], allData, badData, genesToQuery,boundry,negBoundry)

		allData.each do |alterationType,profiles|
			profiles.each do |gene, counts|
				#table << "<tr><td>#{params[:cancerStudy]}</td><td>#{alterationType}</td>"
				table << "<td>#{gene}</td>"
				abovePercentage =  "%.2f" % (counts["aboveCount"].to_f / counts["count"].to_f * 100.0)
				aboveMean = roundNumber(counts["aboveSum"].to_f / counts["aboveCount"].to_f)
				table << "<td>#{counts["count"]}</td><td>#{counts["aboveCount"]}</td><td>#{abovePercentage}%</td><td>#{aboveMean}</td>"
				belowPercentage = "%.2f" % (counts["belowCount"].to_f / counts["count"].to_f * 100.0)
				belowMean = roundNumber(counts["belowSum"].to_f / counts["belowCount"].to_f)
				mean = roundNumber(counts["sum"].to_f / counts["count"].to_f)
				table << "<td>#{counts["belowCount"]}</td><td>#{belowPercentage}%</td><td>#{belowMean}</td><td>#{mean}</td></tr>"
			end
		end
		table << "</table>"
		return {"table"=>table,"badData"=>badData.keys}
	end

	def self.queryCbioMutualExclusion(params)
		require 'hypergeo_stats'
		hyp =  HStats::HypergeoStats.new

		fieldErrors={}
		# check to make sure all fields are defined
		["query", "deletions", "organism", "zThresh", "CNV_thresh", "pValueThreshold"].each do |field| # "pValuesToConsider",
			if(!params[field])
				msg = field
				if(field =~ /zthresh/)
					msg = "Z-Score Threshold"
				elsif (field =~ /CNV_thresh/)
					msg = "CNV Threshold"
				elsif (field =~ /pValuesToConsider/)
					msg = "P-Values to consider"
				elsif (field =~ /pValueThreshold/)
					msg = "P-value threshold"
				end
				fieldErrors[field]="Could not find a value for the '#{msg}' field."
			end
		end
		return {"error" => fieldErrors } if(fieldErrors.length > 0)

		# if defined but not a number, then...
		if(!params[:zThresh].numeric?)
			 fieldErrors["zThresh"]="'#{params[:zThresh]}' is not a valid 'Z-Score' value."
		end
		if(!params[:CNV_thresh].numeric?)
			 fieldErrors["CNV_thresh"]="'#{params[:CNV_thresh]}' is not a valid 'CNV Threshold' value."
		end
		if(!params[:pValueThreshold].numeric?)
			 fieldErrors["pValueThreshold"]="'#{params[:pValueThreshold]}' is not a valid 'p-value threshold' value."
		end
		params[:pValueThreshold] = params[:pValueThreshold].to_f
		# params[:pValuesToConsider].upcase!
		# if(params[:pValuesToConsider] == 'ALL' && params[:pValuesToConsider] != 'NEGATIVE' && params[:pValuesToConsider] != 'POSITIVE')
		# 	fieldErrors["pValuesToConsider"]="'#{params[:pValuesToConsider]}' is not a valid 'P-Values to consider' value."
		# end

		params[:organism].upcase!
		if(params[:organism] != 'HUMAN' && params[:organism] != 'YEAST')
			 fieldErrors["organism"]="'#{params[:organism]}' is not a valid 'organism' value."
		end

		params[:query]=params[:query].split(/\r|,|\n|,\s+|\s+|\|/).compact.delete_if{|x| x == "" }

		params[:query] = App.checkValidGenes({:genes=>params[:query], :organism=>params[:organism]})
		params[:deletions]=params[:deletions].split(/\r|,|\n|,\s+|\s+|\|/).compact.delete_if{|x| x == "" }
		params[:deletions] = App.checkValidGenes({:genes=>params[:deletions], :organism=>params[:organism]})
		if(params[:query][:goodGenes].length<1)
			fieldErrors["query"] = "0 valid query genes found."
		elsif(params[:deletions][:goodGenes].length < 1)
			fieldErrors["deletions"] =  "0 valid deletion genes found."
		end
		return {"error" => fieldErrors } if(fieldErrors.length > 0)

		# at this point we have valid genes - if they are yeast genes, find their orthologs
		# format should be same as 'goodGenes' - ie an array of objects with the keys 'gene' and 'id'
		genesToQuery = {"query"=>params[:query][:goodGenes],"deletion"=>params[:deletions][:goodGenes]}
		genesToQuery["query"].delete("_size")
		genesToQuery["deletion"].delete("_size")
		queryTable="<table id='geneSummary'><tr>"
		if(params[:organism]=='YEAST')
			queryTable << "<th>Type</th><th>Yeast Gene</th><th>Human Orthog(s)</th></tr>"
			# queryGenes and deletionGenes are the same as their human counterpart, except they have an extra 'orf'
			#  parameter in the hash
			#logger.debug "good query genes: #{params[:query][:goodGenes].inspect}"

			genesToQuery["query"]=App.checkForHumanOrthologs(params[:query][:goodGenes])
			genesToQuery["deletion"]=App.checkForHumanOrthologs(params[:deletions][:goodGenes])
			# make sure orthologs were found for BOTH fields
			if(genesToQuery["query"].length<1)
				extra = params[:query][:goodGenes].length > 1 ? "s" : ""
				fieldErrors["query"] = "0 human orthologs found for the #{params[:query][:goodGenes].length} yeast query gene#{extra} entered."
			elsif(genesToQuery["deletion"].length < 1)
				extra = params[:deletions][:goodGenes].length > 1 ? "s" : ""
				fieldErrors["deletions"] =  "0 human orthologs found for the #{params[:deletions][:goodGenes]} yeast query deletion#{extra} entered."
			end
			return {"error" => fieldErrors } if(fieldErrors.length > 0)

			genesToQuery.each_pair do |type, set|
				orthologs = {}
				set.each do |gene|
					yGeneName = gene["yGene"] != "" ? "#{gene["yGene"]} (#{gene["orf"]})" : gene["orf"]
					geneName = gene["gene"] != "" ? "#{gene["gene"]} (#{gene["id"]})" : gene["id"]
					if(orthologs.has_key?(yGeneName))
						orthologs[yGeneName] << geneName
					else
						orthologs[yGeneName] = [geneName]
					end
				end
				queryTable << "<tr><td rowspan=#{orthologs.length}>#{type.titleize}</td>"
				orthologs.each_pair do |yeast, human|
					human = human.sort.join(", ")
					queryTable << "<td>#{yeast}</td><td>#{human}</td></tr><tr>"
				end
				queryTable.gsub!(/\<tr\>$/,"")
			end
		else
			genesToQuery.each_pair do |type, set|
				hGenes=[]
				queryTable << "<tr><td rowspan=#{genesToQuery[type].length}>#{type.titleize}</td>"
				set.each_pair do |id,gene|
					geneName = gene != "" ? "#{gene} (#{id})" : "#{id}"
					queryTable << "<td>#{geneName}</td></tr><tr>"
					hGenes << {"gene"=>gene,"id"=>id}
				end
				genesToQuery[type]=hGenes
				queryTable.gsub!(/\<tr\>$/,"")
			end
		end
		if(params[:ptenDown]=="true")
			genesToQuery["extra"] = [{"gene"=>"PTEN"}]
		end
		table="<table id='mutExclusionData'><thead><tr><th>Cancer Study</th><th>Alteration Type</th><th>Q Gene</th><th>Gene</th>"
		table<<"<th>N</th><th>K</th><th>n</th><th>k</th><th>P-Value</th></thead><tbody>"

		cancerStudies = getAllCancerStudies(params[:app][:cancerStudy])

		badData = {} # ??

		# iterate over all cancer studies
		# in each row index 0 == cancer_study_id, 1 == name, 2 == description
		# the cancer_study_id == a unique integer ID that should be used to identify the cancer study in subsequent interface calls.

		studyCount = 1;
		cancerStudies.each{|cancerStudy|
			cancerStudyId = cancerStudy[0]
			caseListId = getCaseList(cancerStudyId, {:max => true})
			return caseListId if(caseListId.has_key?("error"))
			geneticProfileIds = get_CNA_and_mRNA_Genetic_Profiles(cancerStudyId)
			return geneticProfileIds if geneticProfileIds.has_key?("error")
			# geneticProfileIds is a hash with the following keys:
			# mRNAid_ideal => a string holding the ideal mRNA genetic_profile_id
			# cnvID_ideal => a string holding the ideal CNA genetic_profile_id
			# mRNAid_other => an array holding the other mRNA genetic_profile_id(s)
			# cnvID_other => an array holding the other CNV genetic_profile_id(s)

			#ProcessLog.updateProcessLog(params[:stamp],10,"")

			# initialize hash to be a hash of hashes
			allData = Hash.new(&(p=lambda{|h,k| h[k] = Hash.new(&p)}))
			getAllProfileData(buildGeneticProfileIdParam(geneticProfileIds), caseListId["good"], allData, badData, genesToQuery)

			rowFront = "<tr><td>#{cancerStudy[1]}</td>"
			studyCount+=1
			# all data should now contain the following:
			# allData --> "profile id - alteration type" --> tumor id --> type (ie, query or deletion) --> gene --> score
			# iterate over structure, only consider tumors which contain info about both gene types (ie dataon the gene overexpressed and the gene deleted)

			ptenCounter = {};

			allData.each do |alterationType,profiles|
				ptenCounter[alterationType]=0
				output={}
				genesToQuery["query"].each do |qGene|
					output[qGene["gene"]] = {}
					genesToQuery["deletion"].each do |gene|
						# create 3 x 3 array initialized to 0
						#puts "#{qGene["gene"]} -  #{gene["gene"]}\n"
						output[qGene["gene"]][gene["gene"]]=Array.new(3){Array.new(3){0}}
					end
				end
				boundry = nil
				# if we can id this data as CNA or mRNA z-scores, then...
				if(alterationType =~ /gistic/i)
					boundry = params[:CNV_thresh].to_f
				elsif(alterationType =~ /zscore/i || alterationType =~ /z_score/i || alterationType =~ /z-score/i)
					boundry = params[:zThresh].to_f
				else
					badData["Warning! #{alterationType} data not processed because I don't know how to process it."]=1
				end
				totalTumors=0
				if(!boundry.nil?)
					negBoundry = boundry * -1.0
					profiles.each do |tumor, geneType|
						# if this tumor does not contain data on both the deletion AND the query
						continueFlag = true
						if(geneType["deletion"].length < 1 || geneType["query"].length < 1)
							profiles.delete(tumor)
							continueFlag = false
						elsif(geneType.has_key?("extra"))
							geneType["extra"].each do |extraName, extraScore|
								temp = false
								if(extraScore.to_f <= negBoundry)
									temp=true
								end
								continueFlag = continueFlag && temp
							end
						end
						if(continueFlag)
							geneType["query"].each do |qGeneName, qScore|
								if(!output[qGeneName])
									badData["Warning! No Data for #{geneName}!"]=1
								else
									qScore = qScore.to_f
									if(qScore >= boundry)
										bin=0
									elsif(qScore <= negBoundry)
										bin=1
									else
										bin=2
									end
									geneType["deletion"].each do |geneName, dScore|
										dScore = dScore.to_f
										#puts "#{qGeneName} == #{geneName}"
										#puts "#{output[qGeneName][geneName]}"
										if(!output[qGeneName][geneName])
											badData["Warning! No Data for #{geneName}!"]=1
										else
											if(dScore >= boundry)
												output[qGeneName][geneName][bin][0]+=1
											elsif(dScore <= boundry*-1)
												output[qGeneName][geneName][bin][1]+=1
											else
												output[qGeneName][geneName][bin][2]+=1
											end
										end
									end
								end
							end
						end
					end
					# now output1 should contain all the numbers we need, in the 3x3 matrix
					# index 0 = upregulated
					# 1 = down
					# 2 = unaffected
					# the 1st value corresponds to the query, the second is the gene deletion
					output.each_pair do |qGene, deletionResults|
						deletionResults.each_pair do |dGene, matrix|
							# sample size = [0][1] + [0][0] + [0][2] == total number of tumors query is up
							# total success = [0][1] + [1][1] + [2][1] == total times deletion is down
							# successes in sample == [0][1] == total times deletion down when query is up
							# N = sum
							# [0][1] query up, deletion down
							# [0][0] + [0][2] query up, deletion up / unaffected
							# [1][1]
							t = matrix[0][0]+matrix[0][1]+matrix[0][2]+matrix[1][0]+matrix[1][1]+matrix[1][2]+matrix[2][0]+matrix[2][1]+matrix[2][2] # N
							tg = matrix[0][1]+matrix[1][1]+matrix[2][1] # K
							tp = matrix[0][1]+matrix[0][0]+matrix[0][2] # n
							gp = matrix[0][1] # k
							if(t>50)
								pVal = ["na"]
								if(t < 0 || tg < 1)
									pVal = ["na"]
								else
									pVal = hyp.cum_hyperg_pval_info(gp,tg,tp,t)
									if(pVal[0].abs < params[:pValueThreshold]) # pVal[0] < 0 &&
										if(pVal[0].abs < 0.001)
											pVal[0] = "%.3E" % pVal[0]
										else
											pVal[0] = "%.3g" % pVal[0]
										end
										table << "#{rowFront}<td>#{alterationType}</td><td>#{qGene}<td>#{dGene}</td><td>#{t}</td><td>#{tg}</td><td>#{tp}</td><td>#{gp}</td><td class='nw'>#{pVal[0]}</td></tr>"
									end
								end
							end
						end
					end
				end
			end
		}
		return {"table" => "#{table}</tbody></table>", "geneSummary" => "#{queryTable}</table>","badData"=>badData.keys}
	end

	def self.runAPIrequest(params)
		http = 'http://www.cbioportal.org/public/webservice.do'
		begin
			response = Net::HTTP.get(URI("#{http}?#{App.parameterize(params)}"))
		rescue => err
			#puts "Exception: #{err}"
			#err
			return "ERROR"
		end
		parsed_file = CSV.parse(response, { :col_sep => "\t",:quote_char => "|" })
		warnings = []
		while(parsed_file[0][0].chars.first == '#')
			if(parsed_file[0][0] =~ /Warning\:/)
				warnings << parsed_file[0][0].gsub("#","").strip
			end
			parsed_file.shift
		end
		# next list should be headers
		headers=parsed_file.shift
		return parsed_file, headers, warnings
	end

	def self.getAllCancerStudies(studyID="")
		params = { :cmd=>'getCancerStudies'}
		(allCancerStudies,headers) = runAPIrequest(params)
		if(allCancerStudies == 'ERROR')
			return ['error']
		elsif(!studyID || studyID == "" || studyID == "all")
			return allCancerStudies
		else
			allCancerStudies.each do |study|
				if(study[0] == studyID)
					return [study]
				end
			end
		end
		return false
	end

	#  if options => max == true then return only the caseList withthe max # of tumors, if false return
	#  ALL case lists with names and descriptions
	def self.getCaseList(cancerStudyId, options={})
		defaults = {:max => true} # default to true to return just the case list with the max # of tumors
		options = defaults.merge(options)
		# for each cancer_study_id, find all case_list_id
		params = { :cmd=>'getCaseLists'}
		params[:cancer_study_id] = cancerStudyId
		# the getCaseLists command:
		# Retrieves meta-data regarding all case lists (tumor sample subsets) stored about a specific cancer study.
		# e.g., a within a particular study, only some cases (i.e. tumor samples) may have sequence data,
		# and another subset of cases may have been sequenced and treated with a specific therapeutic protocol.
		# We want the case_list_id with the largest number of case_ids --> we want to query all the tumors
		(caseLists,headers) = runAPIrequest(params)
		# each row in caseLists has the following indice:
		# 0 == case_list_id: a unique ID used to identify the case list ID in subsequent interface calls. This is a human readable ID.
		#      For example, "gbm_all" identifies all cases profiles in the TCGA GBM study.
		# 1 == case_list_name: short name for the case list.
		# 2 == case_list_description: short description of the case list.
		# 3 == cancer_study_id: cancer study ID tied to this genetic profile. Will match the input cancer_study_id.
		# 4 == case_ids: space delimited list of all case IDs that make up this case list.
		caseIndex = headers.index('case_ids')
		caseListIdIndex = headers.index('case_list_id')
		caseListNameIndex = headers.index('case_list_name')
		caseListDescriptionIndex = headers.index('case_list_description')
		maxCases=0;
		maxCaseListId=nil
		caseIds = []
		if(!caseIndex.nil? && !caseListIdIndex.nil?)
			caseLists.each { |caseList|
				caseIds << {:id => caseList[caseListIdIndex], :name => caseList[caseListNameIndex], :description => caseList[caseListDescriptionIndex]}
				numCases = caseList[caseIndex].split(" ").length
				if(numCases > maxCases)
					maxCaseListId = caseList[caseListIdIndex]
					maxCases = numCases
				end
			}
		else
		 return {"error"=>["#{headers.join(", ")}"]}
		end
		# maxCaseListId should now hold the id with the maximum number of cases...
		if(options[:max])
			return {"good"=>maxCaseListId}
		end

		return {"good"=>caseIds}
	end


	def self.get_CNA_and_mRNA_Genetic_Profiles(cancerStudyId)
		# attempt to return the genetic_profile_ids associated with ideal CNA or mRNA
		# also only analyze those ids where show_profile_in_analysis_tab == TRUE because
		# i'm assuming this is an interanly file cBio uses to determine whether they show data from
		# a given genetic_profile_id on their website and if it is false, there is likely a good
		# reason why.

		# in this function ideal CNA genetic profiles those analyzed with gistic
		# ideal mRNA == those that have ben merged
		# note in my termonology, CNA is interchagable with CNV
		geneticProfileIDs = {
			:mRNAid_ideal => [], # will hold the ideal mRNA genetic_profile_id
			:cnvID_ideal => [], # will hold the ideal CNA genetic_profile_id
			:mRNAid_other => [],  # will hold the other mRNA genetic_profile_id(s)
			:rna_seq =>[], # will hold rna seq data
			:cnvID_other => []  # will hold the other CNA genetic_profile_id(s)
		}

		# getGeneticProfiles => Retrieves meta-data regarding all genetic profiles,
		# e.g. mutation or copy number profiles, stored about a specific cancer study.
		params = { :cmd=>'getGeneticProfiles'}
		params[:cancer_study_id] = cancerStudyId
		(geneticProfileMetaData,headers) = runAPIrequest(params)
		# each row in geneticProfileMetaData contains:
		# 0 == genetic_profile_id: a unique ID used to identify the genetic profile ID in subsequent interface calls. This is a human readable ID. For example, "gbm_mutations" identifies the TCGA GBM mutation genetic profile.
		# 1 == genetic_profile_name: short profile name.
		# 2 == genetic_profile_description: short profile description.
		# 3 == cancer_study_id: cancer study ID tied to this genetic profile. Will match the input cancer_study_id.
		# 4 == genetic_alteration_type: indicates the profile type. Will be one of:
				 # MUTATION
				 # MUTATION_EXTENDED
				 # COPY_NUMBER_ALTERATION
				 # MRNA_EXPRESSION
				 # METHYLATION
		# 5 == show_profile_in_analysis_tab: a boolean flag used for internal purposes (you can safely ignore it).

		geneticProfileIdIndex = headers.index('genetic_profile_id')
		geneticProfileNameIndex = headers.index('genetic_profile_name')
		geneticAlterationTypeIndex = headers.index('genetic_alteration_type')
		showProfileInAnalysisTabIndex = headers.index('show_profile_in_analysis_tab')
		# if these columns are undefined, then  we have a big problem
		if(geneticProfileIdIndex.nil? || geneticAlterationTypeIndex.nil?|| showProfileInAnalysisTabIndex.nil? || geneticProfileNameIndex.nil?)
			return {"error" => "Error finding indexes of geneticProfileMetaData for cancers study id = '#{cancerStudyId}'!<br/>Headers:<br/>#{headers.join(", ")}"}
		end
		geneticProfileMetaData.each { |geneticProfile|
			if(geneticProfile[geneticAlterationTypeIndex] == 'COPY_NUMBER_ALTERATION')
				if(geneticProfile[geneticProfileIdIndex] =~ /gistic/i)
					if(geneticProfileIDs[:cnvID_ideal].length ==0)
						geneticProfileIDs[:cnvID_ideal] << {"id"=>geneticProfile[geneticProfileIdIndex], "name"=>geneticProfile[geneticProfileNameIndex]}
					else
						#puts "Error! cnvID_ideal already defined -- #{cnvID_ideal}"
					end
				else
				 geneticProfileIDs[:cnvID_other] << {"id"=>geneticProfile[geneticProfileIdIndex], "name"=>geneticProfile[geneticProfileNameIndex]}
				end
			elsif(geneticProfile[geneticAlterationTypeIndex] == 'MRNA_EXPRESSION')
				if(geneticProfile[geneticProfileIdIndex] =~ /merged/i)
					if(geneticProfileIDs[:mRNAid_ideal].length ==0)
						geneticProfileIDs[:mRNAid_ideal] << {"id"=>geneticProfile[geneticProfileIdIndex], "name"=>geneticProfile[geneticProfileNameIndex]}
					else
						#puts "Error! mRNAid_ideal already defined -- #{mRNAid_ideal}"
					end
				elsif(geneticProfile[geneticProfileIdIndex] =~ /z-scores/)
					geneticProfileIDs[:mRNAid_other].unshift({"id"=>geneticProfile[geneticProfileIdIndex], "name"=>geneticProfile[geneticProfileNameIndex]})
				elsif(geneticProfile[geneticProfileIdIndex] =~ /rna_seq/)
					geneticProfileIDs[:rna_seq] << {"id"=>geneticProfile[geneticProfileIdIndex], "name"=>geneticProfile[geneticProfileNameIndex]}
				# else
				# 	puts "ignoring #{geneticProfile[geneticProfileIdIndex]} data"
				end
			end
		}
		return geneticProfileIDs
	end

	def self.buildGeneticProfileIdParam(geneticProfileIds)
		idInfo = {:genetic_profile_id=>[]}
		if(geneticProfileIds[:mRNAid_ideal].length >0)
			idInfo[:typeOfAlteration] = "MRNA_EXPRESSION"
			idInfo[:genetic_profile_id] << geneticProfileIds[:mRNAid_ideal]

		elsif(geneticProfileIds[:mRNAid_other].length == 1)
			idInfo[:typeOfAlteration] = "MRNA_EXPRESSION"
			idInfo[:genetic_profile_id] << geneticProfileIds[:mRNAid_other]
		elsif(geneticProfileIds[:mRNAid_other].length > 1)
			idInfo[:typeOfAlteration] = "MRNA_EXPRESSION"
			idInfo[:genetic_profile_id] << geneticProfileIds[:mRNAid_other]
		end
		if(geneticProfileIds[:rna_seq].length >0)
			idInfo[:typeOfAlteration] = "MRNA_EXPRESSION"
			idInfo[:genetic_profile_id] << geneticProfileIds[:rna_seq]
		end
		if(geneticProfileIds[:cnvID_ideal].length >0)
			idInfo[:typeOfAlteration] = "COPY_NUMBER_ALTERATION"
			idInfo[:genetic_profile_id] << geneticProfileIds[:cnvID_ideal]
		elsif(geneticProfileIds[:cnvID_other].length == 1)
			idInfo[:typeOfAlteration] = "COPY_NUMBER_ALTERATION"
			idInfo[:genetic_profile_id] << geneticProfileIds[:cnvID_other]
		elsif(geneticProfileIds[:cnvID_other].length > 1)
			idInfo[:typeOfAlteration] = "COPY_NUMBER_ALTERATION"
			idInfo[:genetic_profile_id] << geneticProfileIds[:cnvID_other]
		end
		idInfo[:genetic_profile_id] = idInfo[:genetic_profile_id].flatten.map{|hash| hash["id"] }.flatten
		return idInfo
	end

	def self.summarizeProfileData(geneticProfileIds, caseListId, allData, badData, genesToQuery,boundry,negBoundry)
		# getAllProfileData => Retrieves genomic profile data for one or more genes.
		params = { :cmd=>'getProfileData'}
		params[:case_set_id] = caseListId
		params[:gene_list]=''
		currentGenes = {}
		count = 0;
		geneticProfileIds[:genetic_profile_id].each do |profileID|
			params[:genetic_profile_id] = profileID
			genesToQuery.each { |type, queryGene|
				queryGene.each do |gene|
					count+=1
					currentGenes[gene["gene"]]=type
					if(count % 500 == 0)
						params[:gene_list] = currentGenes.keys.join(',')
						#puts "request # #{count}"
						runSummaryProfileQuery(params,allData,boundry,negBoundry,badData)
						currentGenes={}
					end
				end
			}
			if(currentGenes.length>0)
				#puts "request # #{count}"
				params[:gene_list] = currentGenes.keys.join(',')
				runSummaryProfileQuery(params,allData,boundry,negBoundry,badData)
				currentGenes={}
			end
		end
	end

	def self.runSummaryProfileQuery(params,allData,boundry,negBoundry,badData)
		(profileData,headers,warnings) = runAPIrequest(params)
		warnings.each do |value|
			badData[value]=1
		end
		geneNameIndex = headers.index('COMMON')
		if( geneNameIndex.nil?)
			badData["Bad profile data for: '#{params[:genetic_profile_id]}' -- '#{params[:case_set_id]}' - gene = '#{params[:gene_list]}', could find indexes.<br/>#{headers.join(", ")}"]=1
		else
			#wantedTumors = {'TCGA-A2-A0T2' => 1, 'TCGA-A2-A04P' => 1, 'TCGA-A1-A0SK' => 1, 'TCGA-A2-A0CM' => 1, 'TCGA-AR-A1AR' => 1, 'TCGA-B6-A0WX' => 1, 'TCGA-BH-A1F0' => 1, 'TCGA-B6-A0I6' => 1, 'TCGA-BH-A18V' => 1, 'TCGA-BH-A18Q' => 1, 'TCGA-BH-A18K' => 1, 'TCGA-BH-A0HL' => 1, 'TCGA-BH-A0E0' => 1, 'TCGA-BH-A0RX' => 1, 'TCGA-A7-A13D' => 1, 'TCGA-BH-A0E6' => 1, 'TCGA-AO-A0J4' => 1, 'TCGA-A7-A0CE' => 1, 'TCGA-A7-A13E' => 1, 'TCGA-A7-A0DA' => 1, 'TCGA-D8-A142' => 1, 'TCGA-D8-A143' => 1, 'TCGA-AQ-A04J' => 1, 'TCGA-BH-A0HN' => 1, 'TCGA-A2-A0T0' => 1, 'TCGA-A2-A0YE' => 1, 'TCGA-A2-A0YJ' => 1, 'TCGA-A2-A0D0' => 1, 'TCGA-A2-A04U' => 1, 'TCGA-AO-A0J6' => 1, 'TCGA-A2-A0YM' => 1, 'TCGA-A2-A0D2' => 1, 'TCGA-BH-A0B3' => 1, 'TCGA-A2-A04Q' => 1, 'TCGA-A2-A0SX' => 1, 'TCGA-AO-A0JL' => 1, 'TCGA-AO-A12F' => 1, 'TCGA-BH-A0B9' => 1, 'TCGA-A2-A04T' => 1, 'TCGA-B6-A0RT' => 1, 'TCGA-AO-A128' => 1, 'TCGA-AO-A129' => 1, 'TCGA-AO-A124' => 1, 'TCGA-B6-A0RU' => 1, 'TCGA-B6-A0IQ' => 1, 'TCGA-B6-A0I2' => 1, 'TCGA-B6-A0IJ' => 1, 'TCGA-B6-A0X1' => 1, 'TCGA-B6-A0RE' => 1, 'TCGA-A2-A0ST' => 1, 'TCGA-AR-A0TP' => 1, 'TCGA-A1-A0SO' => 1, 'TCGA-A8-A07C' => 1, 'TCGA-A8-A07O' => 1, 'TCGA-A8-A07R' => 1, 'TCGA-A8-A07U' => 1, 'TCGA-A8-A08H' => 1, 'TCGA-A8-A08R' => 1, 'TCGA-AN-A04D' => 1, 'TCGA-AN-A0AL' => 1, 'TCGA-AN-A0AR' => 1, 'TCGA-AN-A0AT' => 1, 'TCGA-AN-A0FJ' => 1, 'TCGA-AN-A0FL' => 1, 'TCGA-AN-A0FX' => 1, 'TCGA-AN-A0G0' => 1, 'TCGA-AN-A0XU' => 1, 'TCGA-AR-A0TS' => 1, 'TCGA-AR-A0TU' => 1, 'TCGA-AR-A0U0' => 1, 'TCGA-AR-A0U1' => 1, 'TCGA-AR-A0U4' => 1, 'TCGA-AR-A1AH' => 1, 'TCGA-AR-A1AI' => 1, 'TCGA-AR-A1AJ' => 1, 'TCGA-AR-A1AQ' => 1, 'TCGA-AR-A1AY' => 1, 'TCGA-BH-A0AV' => 1, 'TCGA-BH-A0BG' => 1, 'TCGA-BH-A0BL' => 1, 'TCGA-BH-A0BW' => 1, 'TCGA-BH-A0DL' => 1, 'TCGA-BH-A0WA' => 1, 'TCGA-BH-A18G' => 1, 'TCGA-C8-A12K' => 1, 'TCGA-C8-A12V' => 1, 'TCGA-C8-A131' => 1, 'TCGA-C8-A134' => 1, 'TCGA-D8-A147' => 1, 'TCGA-E2-A14N' => 1, 'TCGA-E2-A14R' => 1, 'TCGA-E2-A14X' => 1, 'TCGA-E2-A14Y' => 1, 'TCGA-E2-A150' => 1, 'TCGA-E2-A158' => 1, 'TCGA-E2-A159' => 1, 'TCGA-E2-A1AZ' => 1, 'TCGA-E2-A1B5' =>1}
			#indicesToPull=[]
			#headers.each_with_index do |col, index|
			#	indicesToPull << index if(wantedTumors.has_key?(col))
			#end

			profileData.each { |geneticProfile|
				# here geneticProfile[geneNameIndex] MUST be in quotes
				if(!allData[params[:genetic_profile_id]].has_key?("#{[geneticProfile[geneNameIndex]]}"))
					for index in 3..headers.length
						if(geneticProfile[index] !~ /^NAN?$/i)
							allData[params[:genetic_profile_id]][geneticProfile[geneNameIndex]]["sum"] += geneticProfile[index].to_f
							allData[params[:genetic_profile_id]][geneticProfile[geneNameIndex]]["count"]+=1
							if(geneticProfile[index].to_f >= boundry)
								allData[params[:genetic_profile_id]][geneticProfile[geneNameIndex]]["aboveCount"]+=1
									allData[params[:genetic_profile_id]][geneticProfile[geneNameIndex]]["aboveSum"]+=geneticProfile[index].to_f
							elsif(geneticProfile[index].to_f <= negBoundry)
								allData[params[:genetic_profile_id]][geneticProfile[geneNameIndex]]["belowSum"]+=geneticProfile[index].to_f
								allData[params[:genetic_profile_id]][geneticProfile[geneNameIndex]]["belowCount"]+=1
							end
						end
					end
				end
			}
		end
	end

	def self.getAllProfileData(geneticProfileIds, caseListId, allData, badData, genesToQuery)
		# getAllProfileData => Retrieves genomic profile data for one or more genes.
		params = { :cmd=>'getProfileData'}
		params[:case_set_id] = caseListId
		currentGenes={}
		count=0
		genesToQuery.each { |type, queryGene|
			queryGene.each do |gene|
				count+=1
				currentGenes[gene["gene"]]=1 # avoid dups
				if(count % 500 == 0)
					runAllDataProfileQuery(params,currentGenes,allData,badData,geneticProfileIds,type)
					currentGenes={}
				end
			end
			if(currentGenes.length>0)
				runAllDataProfileQuery(params,currentGenes,allData,badData,geneticProfileIds,type)
				currentGenes={}
			end
		}
	end

	def self.runAllDataProfileQuery(params,currentGenes,allData,badData,geneticProfileIds,type)
		params[:gene_list] = currentGenes.keys.join(',')
		geneticProfileIds[:genetic_profile_id].each do |profileID|
			params[:genetic_profile_id] = profileID
			(profileData,headers,warnings) = runAPIrequest(params)
			warnings.each do |value|
				badData[value]=1
			end

			geneNameIndex = headers.index('COMMON')
			if( geneNameIndex.nil?)
				badData["Bad profile data for: '#{params[:genetic_profile_id]}' -- '#{params[:case_set_id]}' - gene = '#{params[:gene_list]}', could find indexes.<br/>#{headers.join(", ")}"]=1
			else
				profileData.each { |geneticProfile|
					for index in 3..headers.length
						if(geneticProfile[index] !~ /^NAN?$/i)
							allData["#{params[:genetic_profile_id]}"]["#{headers[index]}"][type][geneticProfile[geneNameIndex]] = geneticProfile[index]
						end
					end
				}
			end
		end
		return 1
	end

end