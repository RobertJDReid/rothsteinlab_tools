class CbioController < ApplicationController

	def mutual_exclusion
	  @title="Query the MSKCC cBio Portal"
	  @header="<h1><i>#{@title}</i></h1><em>For mutual exclusion.</em>"
	  if(params[:query])
	    # @table = ProcessLog.setProcessLog(params[:stamp])
	    render :json => Cbio.queryCbioMutualExclusion(params) #if !@table.has_key?("error")
	  else
	    @studies = Cbio.getAllCancerStudies()
	    # temp = @studies.map {|s| s[0] }
	    unless (!@studies || @studies[0] == 'error')
	    	@studies.unshift(["all", "All"])
	    end
	  end
	end

	def scores
	  @title="Query the MSKCC cBio Portal Scores"
	  @header="<h1><i>#{@title}</i></h1><p>Human Genes Only!"
	  @studies = Cbio.getAllCancerStudies()
	  # temp = @studies.map {|s| s[0] }
	  # @studies.unshift(["all", "All"])
	end

	def getAlterationTypes
	  @results = Cbio.get_CNA_and_mRNA_Genetic_Profiles(params[:cancerStudyID])
	  if(@results.has_key?("error"))
	    render :json=>@results
	  else
	    render :json => @results.sort_by { |k,v| k.to_s }.map{|a| a[1]}.flatten
	  end
	end

	def getCaseList
	  @results = Cbio.getCaseList(params[:cancerStudyID], {:max => false})
	  if(@results.has_key?("error"))
	    render :json=>@results
	  else
	    render :json=>@results.sort_by { |k,v| k.to_s }.map{|a| a[1]}.flatten
	  end
	end

	def getCbioScores
	  render :json=>Cbio.getCbioScores(params[:app])
	end  

end