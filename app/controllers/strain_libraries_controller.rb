class StrainLibrariesController < ApplicationController

  def edit
    @title="Edit Strain Library Information"
    @header="<h1>#{@title}</h1>"
    @strain_library = StrainLibrary.find(params[:id])
    @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
  end
  
  def update
    @strain_library= StrainLibrary.find(params[:id])
    params[:strain_library][:updated_by] = current_user.login
    if @strain_library.update_attributes(library_update_params)
      flash[:notice] = "Strain Library '#{@strain_library.name}' was successfully updated."
      redirect_to :action => 'list'
    else
      @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
      render :action => 'edit'
    end
  end
   
  def list
    @title="Current Rothstein Lab Strain Libraries"
    @header="<h1>#{@title}</h1>"
    @libraries=StrainLibrary.all
  end
  
  def create
    @strain_library= StrainLibrary.new(library_params)
    if @strain_library.save
      flash[:notice] = "Strain Library '#{@strain_library.name}' Created Successfully!"
      redirect_to :action => 'list'
    else
      @title="Create A New Rothstein Lab Strain Library"
      @header="<h1>#{@title}</h1>"
      @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
      flash[:error] = 'Strain Library was not successfully created.'
      render :action => 'new'
    end
  end

  def new 
    @strain_library= StrainLibrary.new
    @title="Create A New Rothstein Lab Strain Library"
    @header="<h1>#{@title}</h1>"
    @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
  end

  private

  def library_params
    params.require(:strain_library).permit(:name, :updated_by, :created_at, :mating_type, :selectable_marker, :key_file_location, :background, :updated_at)
  end

  def library_update_params
    params.require(:strain_library).permit(:name, :updated_by, :mating_type, :selectable_marker, :key_file_location, :background, :updated_at)
  end



end