class Network < ActiveRecord::Base

	def self.getFeatureData(params)
		# check to make sure all fields are defined
		fieldErrors=Network.checkParams(params, ["organism", "feature", "genes"])
		return {"error" => fieldErrors } if(fieldErrors.length > 0)
		if(params[:organism] == 'scerevisiae')
			if(params[:feature].upcase == 'GO PROCESS')
				return ScerevisiaeGoProcessAssociations.getSignificantGOmembership(params[:genes],0.05)
			elsif (params[:feature].upcase == 'COMPLEX MEMBERSHIP')
				return ScerevisiaeBaryshnikovaComplexData.getSignificantComplexMembership(params[:genes],0.05)
			end
		elsif(params[:organism] == 'spombe')
			if(params[:feature].upcase == 'GO PROCESS')
				return {} #SpombeGoProcessAssociations.getSignificantGOmembership(params[:genes])
			elsif (params[:feature].upcase == 'COMPLEX MEMBERSHIP')
				return {} #SpombeComplex.getComplexMembership(params[:genes])
			end
		end
	end

	def self.buildNetwork(params)
		# check to make sure all fields are defined
		fieldErrors=Network.checkParams(params, ["organism", "genes"])
		if(!params["interactions"] || params["interactions"].length<1)
			params["interactions"]=[]
		end
		return {"error" => fieldErrors } if(fieldErrors.length > 0)
		if(params[:organism] == 'scerevisiae')
			return ScerevisiaeBioGridInteractions.getInteractions(params[:genes],params[:interactions])
		elsif(params[:organism] == 'spombe')
			return SpombeBioGridInteractions.getInteractions(params[:genes],params[:interactions])
		end
		return {"error" => "Unknown organism selected!"};
	end

	protected

	def self.checkParams(params, requiredParamNames)
		fieldErrors = {}
		requiredParamNames.each do |field| # "pValuesToConsider",
			if(!params[field])
				fieldErrors[field]="Could not find a value for the '#{field}' field."
			elsif(params[field].length < 1)
				if(params[field].is_a?(String))
					fieldErrors[field]="There must be at least one character in the '#{field}' field (it is currently blank)."
				else
					fieldErrors[field]="There must be at least one item in the '#{field}' field."
				end
			end
		end
		return fieldErrors
	end
end