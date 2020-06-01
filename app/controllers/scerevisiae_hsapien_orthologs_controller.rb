class ScerevisiaeHsapienOrthologsController < ApplicationController

	def edit
    @title="Edit ortholog information"
    @header="<h1>#{@title}</h1>"
    @scerevisiaeHumanOrtholog = ScerevisiaeHsapienOrtholog.find(params[:id])
  end
  
  def update
    @scerevisiaeHumanOrtholog = ScerevisiaeHsapienOrtholog.find(params[:id])
    ScerevisiaeHsapienOrtholog.processParams(params, current_user)
    # if(@scerevisiaeHumanOrtholog.yeastOrf == params[:scerevisiae_hsapien_ortholog][:yeastOrf] && @scerevisiaeHumanOrtholog.humanEnsemblID==params[:scerevisiae_hsapien_ortholog][:humanEnsemblID])
      # params[:scerevisiae_hsapien_ortholog].delete("humanEnsemblID") # need to delete this and the next one to prevent duplicate keys
      # params[:scerevisiae_hsapien_ortholog].delete("yeastOrf")
    # end
    #puts params[:scerevisiae_hsapien_ortholog].inspect
    if @scerevisiaeHumanOrtholog.update_attributes(ortholog_update_params)
      flash[:notice] = "<i>S. cerevisiae / human ortholog  pair - '#{@scerevisiaeHumanOrtholog.yeastOrf} - #{@scerevisiaeHumanOrtholog.humanGeneName}' was successfully updated."
      redirect_to :action => 'list'
    else
      @title="Edit ortholog information"
      @header="<h1>#{@title}</h1>"
      flash[:error] = '<i>S. cerevisiae</i> / human ortholog pair was not successfully updated.'
      render :action => 'edit'
    end
  end
   
  def list
    @title="Current Rothstein lab S. cerevisiae / human ortholog pairs"
    @header="<h1><i>S. cerevisiae</i> to human ortholog pairs</h1><em>As cataloged Rothstein lab.</em>"
    
    @scerevisiaeHumanOrthologs=ScerevisiaeHsapienOrtholog.includes(:scerevisiae_gene)
    #  below commented out in favor of above b/c above is more efficient....Eager Loading Associations ftw!
    #@scerevisiaeHumanOrthologs=ScerevisiaeHsapienOrtholog.joins('INNER JOIN `scerevisiae_genes` ON `scerevisiae_genes`.orf = `scerevisiae_hsapien_orthologs`.yeastOrf').select('`scerevisiae_hsapien_orthologs`.*, `scerevisiae_genes`.`gene` as "yeastGene"')
  end
  
  def create
    ScerevisiaeHsapienOrtholog.processParams(params, current_user)
    params[:scerevisiae_hsapien_ortholog][:approved] = true
    @scerevisiaeHumanOrtholog = ScerevisiaeHsapienOrtholog.new(ortholog_params)
    if @scerevisiaeHumanOrtholog.save
      flash[:notice] = "<i>S. cerevisiae</i> / human ortholog pair - '#{@scerevisiaeHumanOrtholog.yeastOrf} - #{@scerevisiaeHumanOrtholog.humanGeneName}' created successfully!"
      redirect_to :action => 'list'
    else
      @title="Create A new Rothstein lab S. cerevisiae to human ortholog"
      @header="<h1>Create A new Rothstein lab <i>S. cerevisiae</i> to human ortholog</h1>"
      flash[:error] = '<i>S. cerevisiae</i> / human ortholog pair was not successfully created.'
      render :action => 'new'
    end
  end
  
  def search
    @title="Search for orthologs between S. cerevisiae and humans"
    @header="<h1>Search for orthologs between <i>S. cerevisiae</i> and humans</h1><b>Enter <i>S. cerevisiae</i> ORFs or human gene names / Ensembl IDs</b>"
  end

  def new 
    @scerevisiaeHumanOrtholog = ScerevisiaeHsapienOrtholog.new
    @title="Create a new Rothstein lab S. cerevisiae / human ortholog pair"
    @header="<h1>Create a new Rothstein lab <i>S. cerevisiae</i> / human ortholog pair</h1>"
  end

  def submit
    @title="Submit a new S. cerevisiae / human ortholog pair."
    @header="<h1>Submit a new <i>S. cerevisiae</i> / human ortholog pair.</h1><em>Are we missing something? Please let us know about it by filling out the form below. Thanks!</em>"
    @scerevisiaeHumanOrtholog = ScerevisiaeHsapienOrtholog.new
  end

  def new_pair_submission
    @title="Submit a new S. cerevisiae / human ortholog pair."
    @header="<h1>Submit a new <i>S. cerevisiae</i> / human ortholog pair.</h1><em>Are we missing something? Please let us know about it by filling out the form below. Thanks!</em>"
    ScerevisiaeHsapienOrtholog.processParams(params, current_user)
    # set approved to false
    params[:scerevisiae_hsapien_ortholog][:approved] = false
    @scerevisiaeHumanOrtholog = ScerevisiaeHsapienOrtholog.new(ortholog_params)
    flash[:notice]=''
    if(verify_recaptcha(params))
      if @scerevisiaeHumanOrtholog.save
        @data = params
        if(ScerevisiaeHsapienOrtholog.email_pair("#{@data.inspect}"))
          flash[:notice] = "<i>S. cerevisiae</i> / human ortholog pair - '#{@scerevisiaeHumanOrtholog.yeastOrf} - #{@scerevisiaeHumanOrtholog.humanGeneName}' successfully submitted. Submissions take ~24hrs to be approved before being added to the database."
          redirect_to :action => 'list'
        else
          @scerevisiaeHumanOrtholog.delete
          flash[:error] = "Error! Could not submit ortholog pair. Please try again later."
          render :submit
        end
      else
        flash[:error] = '<i>S. cerevisiae</i> / human ortholog pair was not successfully submitted.'
        render :submit
      end
    else
      flash[:recaptcha_error]=nil
      flash[:error] = "Error! Failed human test. Please try again."
      render :submit
    end
  end

  private

  def ortholog_params
    params.require(:scerevisiae_hsapien_ortholog).permit(:approved, :humanGeneName, :humanEnsemblID, :yeastOrf, :homologyType, :source, :percentIdentityWithRespectToQueryGene, :percentIdentityWithRespectToYeastGene, :tempYeast)
  end

  def ortholog_update_params
    params.require(:scerevisiae_hsapien_ortholog).permit(:created_by, :updated_by, :id,:humanGeneName, :humanEnsemblID, :yeastOrf, :homologyType, :source, :percentIdentityWithRespectToQueryGene, :percentIdentityWithRespectToYeastGene, :tempYeast)
  end

end