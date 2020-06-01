class ReplicatesController < ApplicationController

  def list
    @title="Current Rothstein Lab SDL Screen Replicates"
    @header="<h1>#{@title}</h1>"
    @replicates=Replicate.all
  end
  
  def create
    @replicate = Replicate.new(replicate_params)
    if @replicate.save
      flash[:notice] = "Replicate '#{@replicate.reps}' Created Successfully!"
      redirect_to :action => 'list'
    else
      @title="Create A New Rothstein Lab SDL Screen Replicate."
      @header="<h1>#{@title}</h1>"
      flash[:error] = 'Replicate was not successfully created.'
      render :action => 'new'
    end
  end

  def new 
    @replicate = Replicate.new
    @title="Create A New Rothstein Lab Screen Replicate"
    @header="<h1>#{@title}</h1>"
  end


  private

  def replicate_params
    params.require(:replicate).permit(:reps)
  end
end