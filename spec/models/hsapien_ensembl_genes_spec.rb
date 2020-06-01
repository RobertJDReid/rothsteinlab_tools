require 'spec_helper'

describe HsapienEnsemblGene do
	describe "#findEnsemblFromGene" do
		it "can successfully find valid gene" do
			result = HsapienEnsemblGene.findEnsemblFromGene({scerevisiae_hsapien_ortholog:{humanGeneName: 'PTTG1'}})
			result.has_key?('ensemblID').should == true
			result['ensemblID'].should == 'ENSG00000164611'
		end
		it "cannot find invalid gene id" do
			result = HsapienEnsemblGene.findEnsemblFromGene({scerevisiae_hsapien_ortholog:{humanGeneName: 'ENSG00000164611'}})
			result.should == ''
		end
	end
end