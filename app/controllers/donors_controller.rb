class DonorsController < ApplicationController
  
  def edit
    @title="Edit Donor Strain Information"
    @header="<h1>#{@title}</h1>"
    @donor = Donor.find(params[:id])
    @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
  end
  
  def update
    @donor = Donor.find(params[:id])
    params[:donor][:updated_by] = current_user.login
    if @donor.update_attributes(donor_update_params)
      flash[:notice] = 'Donor strain was successfully updated.'
      redirect_to :action => 'list'
    else
      @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
      render :action => 'edit'
    end
  end
   
  def list
    @title="Current Rothstein Lab SDL Screen Donor Strains"
    @header="<h1>#{@title}</h1>"
    @donors=Donor.all
  end
  
  def create
    params[:donor][:updated_by] = current_user.login
    @donor = Donor.new(donor_params)
    if @donor.save
      flash[:notice] = "Donor '#{@donor.wNumber}' Created Successfully!"
      redirect_to :action => 'list'
    else
      @title="Create A New Rothstein Lab SDL Screen Donor Strain"
      @header="<h1>#{@title}</h1>"
      @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
      flash[:error] = 'Donor was not successfully created.'
      render :action => 'new'
    end
  end

  def new 
    @donor = Donor.new
    @users ||= User.select('login').where("`permissions` IN ('admin','labMember')")
    @title="Create A New Rothstein Lab SDL Screen Donor Strain"
    @header="<h1>#{@title}</h1>"
  end


  private

  def donor_params
    params.require(:donor).permit(:wNumber, :updated_by, :created_at, :mating_type, :genotype, :notes, :created_by, :updated_at)
  end

  def donor_update_params
    params.require(:donor).permit(:wNumber, :updated_by, :mating_type, :genotype, :notes, :created_by, :updated_at)
  end

end