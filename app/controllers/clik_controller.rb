class ClikController < ApplicationController

  def index
    @title         = "Rothstein Lab - CLIK"
    @header        = "<h1><b>C</b>utoff <b>L</b>inked to <b>I</b>nteraction <b>K</b>nowledge</h1><em>A tool to help you mine ranked ordered data efficiently.</em>"
    @version       = App.getBioGridVersion()
    @droid_version = App.getDroID_version()
    @interactions  = App.getInteractionTypes()
  end

  # for use with CLIK
  def update_interactions
    @interactions = App.getInteractionTypes(params);
    if(@interactions[:error])
      render json: @interactions
    else
      render partial: "clik_interactions", locals: {interactions: @interactions}
    end
  end

  def reciprocal_info
    @title  = "CLIK Reciprocal Interactions Explanation"
    @header = "<h1>#{@title}</h1><em>What is a reciprocal interaction?</em>"
  end

  def bin_width
    @title  = "CLIK Bin Width Explanation"
    @header = "<h1>#{@title}</h1><em>What is bin width and how is it calculated?</em>"
  end

  def bootstrapping
    @title  = "CLIK Bootstap Explanation"
    @header = "<h1>#{@title}</h1><em>How are genes bootstrapped?</em>"
  end

  def noise_reduction
    @title  = "CLIK Noise Reduction Explanation"
    @header = "<h1>#{@title}</h1><em>What noise reduction and why you should I care?</em>"
  end

  def scoring
    @title  = "CLIK Scoring Explanation"
    @header = "<h1>#{@title}</h1><em>How are CLIK groups assigned significance (color)?</em>"
  end

  def group
    @title  = "CLIK Group Explanation"
    @header = "<h1>#{@title}</h1><em>What are CLIK groups and what information is included in their output?</em>"
  end

end