class HsapienEnsemblGenesController < ApplicationController

	def getEnsemblID
		# for some reason, in the datafilter if I render :json the browser throws an "unexpected end of input" error
		# when the json is parsed in the js function
		# rendering as text this issue goes away.
	  render :text => HsapienEnsemblGene.findEnsemblFromGene(params).to_json
	end

end
