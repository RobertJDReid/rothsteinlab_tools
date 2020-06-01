class AppsController < ApplicationController

	def pull_gene_names
		@title="Rothstein Lab - Key file generator"
		@header="<h1>Key File Generator</h1><em>A tool to help you generate custom key files.</em>"
		@libraries = StrainLibrary.all
	end

	def dissection_reader
		@title="Rothstein Lab - Dissection Reader"
		@header="<h1>Dissection Reader</h1><em>A macro for ImageJ to measure the colony areas of dissections.</em>"
	end

	def orf_converter
	  @title="Saccharomyces Cerevisiae Gene Identifier Converter"
	  @header="<h1><i>#{@title}</i></h1><em>Identifiers may be systematic ORF ids, gene names, or gene aliases...</em>"
	end

	def aa_mutator
	  @title="Rothstein Lab - Site Directed Mutagenesis / RFLP Calculator"
	  @header="<h1>Site Directed Mutagenesis / RFLP Calculator</h1><em>A tool to aid in the generation sequence mutations.</em>"
	end

	def data_intersection
	  @title="Rothstein Lab - Data Intersection Tool"
	  @header="<h1>Data Intersection Tool</h1><em>A tool to help you determine the common data that exists in multiple data sets.</em>"
	end

	def calculate_intersection
	  if(params[:area1])
	    (@comparisons, @overLapCount, @uniques) = App.getDatasetOverlaps(params)
	    render :partial=>'overlap_results'
	  end
	end

	def generate_CDF
	  @title="CDF plot generator"
	  @header="<h1><i>#{@title}</i></h1><em>Plot that data!</em>"
	end

	def hyper_geometric_calculator
		@title="Hypergeometric Calculator"
		@header="<h1><i>#{@title}</i></h1><em>The Hypergeometric Calculator makes it easy to compute individual and cumulative hypergeometric probabilities.</em>"
	end

	def find_GO_terms_or_complexes
	  render :json => App.findGOtermOrComplex(params[:term])
	end

	def checkValidGenes
    @results = App.checkValidGenes(params)
    render :text=>@results.to_json
  end

end