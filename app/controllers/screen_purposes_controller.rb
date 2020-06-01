class ScreenPurposesController < ApplicationController

  def list
    @title="Current Rothstein Lab Screen Purposes"
    @header="<h1>#{@title}</h1>"
    @screen_purposes=ScreenPurpose.all
  end
  
  def create
    @screen_purpose = ScreenPurpose.new(params[:screen_purpose])
    if @screen_purpose.save
      flash[:notice] = "Screen Purpose '#{@screen_purpose.purpose}' Created Successfully!"
      redirect_to :action => 'list'
    else
      @title="Create A New Rothstein Lab Screen Purpose"
      @header="<h1>#{@title}</h1>"
      flash[:error] = 'Screen Purpose was not successfully created.'
      render :action => 'new'
    end
  end

  def new 
    @screen_purpose = ScreenPurpose.new
    @title="Create A New Rothstein Lab Screen Purpose"
    @header="<h1>#{@title}</h1>"
  end

  private

  def screen_purpose_params
    params.require(:screen_purpose).permit(:purpose)
  end

end