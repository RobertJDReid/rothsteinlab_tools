class ExperimentsController < ApplicationController

	def dr_engine_file_upload
	  @title="ScreenMill Results - DR Engine File Upload"
	  @bg_image ="/tools/images/rotorimage.gif"
	  @header="<h1>#{@title}</h1><em>Upload your screen data. DO IT!</em>"
	  @repPossibilities=Replicate.getRepPossibilities()
	  @densityPossibilities=Density.getDensityPossibilities()
	  @donors = Donor.all
	  @libraries = StrainLibrary.all
	  @comparers = PwjPlasmid.where('empty_vector IS true').select("number")
	  @purpose = ScreenPurpose.all
	end
	
	def check_if_experiment_exists
	  e = Experiment.doesExperimentAlreadyExist(params[:query], params[:condition])
	  render :json => e.to_json
	end

	def verify_query
	  @queryData = PwjPlasmid.validateQuery(params[:query], params[:condition])
	  render :text => @queryData.to_json
	end

	def update
	  @experiment = current_resource
	  params[:experiment][:updated_by] = current_user.login
	  if @experiment.update_attributes(experiment_update_params)
	    flash[:notice] = 'Experiment was successfully updated.'
	    redirect_to :action => 'list'
	  else
	    render :action => 'edit'
	  end
	end

	def update_comment
	  if(params[:id] && params[:comments])
	    @experiment = Experiment.find(params[:id])
	    if(current_user.login == @experiment.performed_by)
	      if @experiment.update_attributes(:comments => params[:comments])
	        render :text => {'success'=>'Experiment was successfully updated.'}.to_json
	      else
	        render :text => {"error"=>"Failed to update comment because of a server error."}.to_json
	      end
	    else
	      render :text => {"error"=>"Failed to update comment because you do not have permission to modify this experiment."}.to_json
	    end
	  else
	    render :text => {"error"=>"Failed to update comment because invalid params sent."}.to_json
	  end
	end
	 
	def list
	  @title="Rothstein Lab Screens"
	  @header="<h1>#{@title}</h1><em>Displaying all experiments.</em>"
	  @experiments||=Experiment.all
	end

	def associated_data
	  if(params[:id])
	    @experiment = current_resource
	    if(@experiment.id)
	      @title="Rothstein Lab Screen Data"
	      @header="<h1>#{@title}</h1>"
	      @screen_data = ScreenResult.where("`experiment_id`=?",@experiment.id)
	    else
	      flash[:error] = "Invalid experimental id."
	      redirect_to :action => 'list'
	    end
	  else
	    flash[:error] = "Invalid experimental id."
	    redirect_to :action => 'list'
	  end

	  rescue ActiveRecord::RecordNotFound
	    flash[:error] = "Record not found." 
	    redirect_to :action => 'list'
	    
	end

	def my_experiments
	  @title="My Screens"
	  @header="<h1>#{@title}</h1><em>Displaying your (#{current_user.login}) experiments.</em>"
	  @experiments=Experiment.where("`performed_by` = ?", current_user.login)
	  render :action => 'list'
	end

	def destroy
		@experiment = current_resource
	  Experiment.find(params[:id]).destroy
	  flash[:notice] = 'Screen was successfully deleted.'
	  redirect_to experiments_url, notice: 'Screen was successfully deleted.'
	end

	def search
	  @title="Search Rothstein lab screen data"
	  @header="<h1>#{@title}</h1>"
	end

	def deletion_search
	  if(params[:query])
	    orf = ScerevisiaeGene.checkValidOrf(params[:query])
	    if(orf.error)
	      render :text => orf.to_json
	    else
	      @results = ScreenResult.findScreenResults(orf.orf)
	    end
	  else
	    render :text => {"error"=>"Failed to update comment because invalid params sent."}.to_json
	  end
	end

	def associate_experiment_with_colony_data
		@title="Experiment-Colony data association"
		@header="<h1>#{@title}</h1><em>Associate experiments with their associated raw colony data.</em>"
		@experiments=Experiment.where("`performed_by` = ?", current_user.login)
		@colony_data = ExperimentRawDataset.where("`updated_by` = ?", current_user.login)
	end

	def link_data
		@experiment = current_resource
		if @experiment.update_attributes(experiment_update_link)
		  render :json  => {'success' => "Experiment #{@experiment.id} was successfully updated.",  'rowNum' => params[:rowNum]}
		else
			render :json  => {'dataSet' => "Experiment id #{@experiment.id}", :errorMsg => @experiment.errors.full_messages}
		end
		
	end

	def show
		@experiment = current_resource
	end

	def edit
		@title="Edit Experiment"
		@header="<h1>#{@title}</h1>"
		@experiment = current_resource
	end

private
	
	def current_resource
		@current_resource ||= Experiment.find(params[:id]) if params[:id]
	end

	def experiment_update_params
		params.require(:experiment).permit(:batch_date, :density, :comparer, :query, :condition, :replicates, :screen_type, :library_used, :donor_strain_used, :comments, :screen_purpose, :updated_by, :number_of_plates, :performed_by, :incubation_temperature, :experiment_comparer_raw_dataset_id, :experiment_query_raw_dataset_id)
	end

	def experiment_update_link
		params.require(:experiment).permit(:experiment_comparer_raw_dataset_id, :experiment_query_raw_dataset_id)
	end


end