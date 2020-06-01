class ExcludedColoniesController < ApplicationController
  before_action :set_excluded_colony, only: [:show, :edit, :update, :destroy]

  # GET /excluded_colonies
  # GET /excluded_colonies.json
  def index
    @excluded_colonies = ExcludedColony.all
  end

  # GET /excluded_colonies/1
  # GET /excluded_colonies/1.json
  def show
  end

  # GET /excluded_colonies/new
  def new
    @excluded_colony = ExcludedColony.new
  end

  # GET /excluded_colonies/1/edit
  def edit
  end

  # POST /excluded_colonies
  # POST /excluded_colonies.json
  def create
    @excluded_colony = ExcludedColony.new(excluded_colony_params)

    respond_to do |format|
      if @excluded_colony.save
        format.html { redirect_to @excluded_colony, notice: 'Excluded colony was successfully created.' }
        format.json { render action: 'show', status: :created, location: @excluded_colony }
      else
        format.html { render action: 'new' }
        format.json { render json: @excluded_colony.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /excluded_colonies/1
  # PATCH/PUT /excluded_colonies/1.json
  def update
    respond_to do |format|
      if @excluded_colony.update(excluded_colony_params)
        format.html { redirect_to @excluded_colony, notice: 'Excluded colony was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @excluded_colony.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /excluded_colonies/1
  # DELETE /excluded_colonies/1.json
  def destroy
    @excluded_colony.destroy
    respond_to do |format|
      format.html { redirect_to excluded_colonies_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_excluded_colony
      @excluded_colony = ExcludedColony.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def excluded_colony_params
      params.require(:excluded_colony).permit(:experiment_id, :experiment_raw_dataset_id, :row, :column)
    end
end
