class PwjPlasmidsController < ApplicationController
  
  def edit
    @title="Edit pWJ Plasmid Information"
    @header="<h1>#{@title}</h1>"
    @pwj_plasmid = PwjPlasmid.find(params[:id])
    @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
  end
  
  def update
    @pwj_plasmid = PwjPlasmid.find(params[:id])
    params[:pwj_plasmid][:updated_by] = current_user.login
    if @pwj_plasmid.update_attributes(pwj_update_params)
      flash[:notice] = "pWJ Plasmid '#{@pwj_plasmid.number}' was successfully updated."
      redirect_to :action => 'list'
    else
      @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
      render :action => 'edit'
    end
  end
   
  def list
    @title="Current Rothstein Lab pWJ Plasmids"
    @header="<h1>#{@title}</h1>"
    @plasmids=PwjPlasmid.all
  end
  
  def create
    @pwj_plasmid = PwjPlasmid.new(pwj_params)
    if @pwj_plasmid.save
      flash[:notice] = "pWJ Plasmid '#{@pwj_plasmid.number}' Created Successfully!"
      redirect_to :action => 'list'
    else
      @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
      @title="Create A New Rothstein Lab pWJ Plasmid"
      @header="<h1>#{@title}</h1>"
      flash[:error] = 'pWJ plasmid was not successfully created.'
      render :action => 'new'
    end
  end

  def new 
    @pwj_plasmid = PwjPlasmid.new
    @title="Create A New Rothstein Lab pWJ Plasmid"
    @header="<h1>#{@title}</h1>"
    @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
  end

  private

  def pwj_params
    params.require(:pwj_plasmid).permit(:number, :promoter, :yeast_selection, :bacterial_selection, :gene, :comments, :parent, :updated_at, :created_at, :created_by, :updated_by, :empty_vector)
  end

  def pwj_update_params
    params.require(:pwj_plasmid).permit(:number, :promoter, :yeast_selection, :bacterial_selection, :gene, :comments, :parent, :updated_at, :created_by, :updated_by, :empty_vector)
  end
end