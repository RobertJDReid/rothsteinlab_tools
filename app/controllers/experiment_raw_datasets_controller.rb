class ExperimentRawDatasetsController < ApplicationController
  before_action :set_experiment_raw_dataset, only: [:show, :destroy]
  
  # GET /experiment_raw_datasets
  # GET /experiment_raw_datasets.json
  def index
    @title="Rothstein lab raw colony size data"
    @header="<h1>#{@title}</h1><em>Log Files!</em>"
    @experiment_raw_datasets = ExperimentRawDataset.all
  end

  # GET /experiment_raw_datasets/new
  def new
    @title="Upload raw colony size data"
    @header="<h1>#{@title}</h1><em>Log Files!</em>"
  end

  def check_if_log_data_exists
    l = ExperimentRawDataset.doesLogDatasetAlreadyExist(params[:plasmid], params[:condition],params[:density])
    render :json => l.to_json
  end

  # DELETE /experiment_raw_datasets/1
  # DELETE /experiment_raw_datasets/1.json
  def destroy
    @experiment_raw_dataset.destroy
    respond_to do |format|
      format.html { redirect_to experiment_raw_datasets_url }
      format.json { head :no_content }
    end
  end

  # GET /experiment_raw_datasets/1
  # GET /experiment_raw_datasets/1.json
  def show
    if(@experiment_raw_dataset.id)
      @title="Rothstein Lab Raw Colony Data"
      @header="<h1>#{@title}</h1><em>Plasmid - #{@experiment_raw_dataset.pwj_plasmid.number}, Condition - #{@experiment_raw_dataset.condition}"
      @experiment_colony_data = ExperimentColonyData.where("`experiment_raw_dataset_id`=?",@experiment_raw_dataset.id)
    else
      flash[:error] = "Invalid dataset id."
      redirect_to :action => 'index'
    end
  end
  
  # GET /experiment_raw_datasets/1/edit
  # def edit
  # end

  # POST /experiment_raw_datasets
  # POST /experiment_raw_datasets.json
  # def create
  #   @experiment_raw_dataset = ExperimentRawDataset.new(experiment_raw_dataset_params)

  #   respond_to do |format|
  #     if @experiment_raw_dataset.save
  #       format.html { redirect_to @experiment_raw_dataset, notice: 'Experiment raw dataset was successfully created.' }
  #       format.json { render action: 'show', status: :created, location: @experiment_raw_dataset }
  #     else
  #       format.html { render action: 'new' }
  #       format.json { render json: @experiment_raw_dataset.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # # PATCH/PUT /experiment_raw_datasets/1
  # # PATCH/PUT /experiment_raw_datasets/1.json
  # def update
  #   respond_to do |format|
  #     if @experiment_raw_dataset.update(experiment_raw_dataset_params)
  #       format.html { redirect_to @experiment_raw_dataset, notice: 'Experiment raw dataset was successfully updated.' }
  #       format.json { head :no_content }
  #     else
  #       format.html { render action: 'edit' }
  #       format.json { render json: @experiment_raw_dataset.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_experiment_raw_dataset
      @experiment_raw_dataset = ExperimentRawDataset.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    # def experiment_raw_dataset_params
    #   params[:experiment_raw_dataset]
    # end
end
