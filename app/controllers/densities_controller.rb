class DensitiesController < ApplicationController
  
  def list
    @title="Current Rothstein Lab SDL Screen Densities"
    @header="<h1>#{@title}</h1>"
    @densities ||= Density.all
  end
  
  def create
    @density = Density.new(params[:density])
    if @density.save
      flash[:notice] = "Density '#{@density.density}' Created Successfully!"
      redirect_to :action => 'list'
    else
      @title="Create A New Rothstein Lab SDL Screen Density."
      @header="<h1>#{@title}</h1>"
      flash[:error] = 'Density was not successfully created.'
      render :action => 'new'
    end
  end

  def new 
    @density = Density.new
    @title="Create A New Rothstein Lab Screen Density"
    @header="<h1>#{@title}</h1>"
  end

  private

  def donor_params
    params.require(:density).permit(:density)
  end

end