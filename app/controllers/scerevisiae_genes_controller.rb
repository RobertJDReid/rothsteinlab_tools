class ScerevisiaeGenesController < ApplicationController

	def validate
		# for some reason, in the datafilter if I render :json the browser throws an "unexpected end of input" error
		# when the json is parsed in the js function
		# rendering as text this issue goes away.
		render :text=> ScerevisiaeGene.checkValidOrf(params[:gene]).to_json
	end
	
end
