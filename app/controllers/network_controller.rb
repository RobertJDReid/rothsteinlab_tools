class NetworkController < ApplicationController
	# for use with network graphs
	def create_graph
    @title="Rothstein Lab - Network Visualization Tool"
    @network = params[:nodesAndEdgesJSON]
    render layout: false
  end

  # for use with network graphs
	def getNodeFeatureData
	  render json: Network.getFeatureData(params)
	end

	def buildNetwork
	  render json: Network.buildNetwork(params)
	end

	def updateInteractions
		@interactions = App.getInteractionTypes(params);
		render json: @interactions
	end

end