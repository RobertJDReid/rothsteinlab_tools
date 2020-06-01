require 'spec_helper'

describe Cbio do

  describe "GET cbio stuff" do
    it "gets getAlterationTypes" do
      alterationTypes = Cbio.get_CNA_and_mRNA_Genetic_Profiles('brca_tcga')
      (alterationTypes.has_key?("error") || alterationTypes.has_key?(:error)).should == false
      # warn alterationTypes.keys.inspect
      alterationTypes.has_key?(:rna_seq).should == true
      alterationTypes.size.should > 1
    end

    it "gets getCaseList" do
      cases = Cbio.getCaseList('brca_tcga', {:max => false})
      (cases.has_key?("error") || cases.has_key?(:error)).should == false
      (cases.has_key?(:good) || cases.has_key?("good")).should == true
      cases["good"].size.should > 5
      cases["good"][0].has_key?(:id).should == true
    end

    it "gets cBioScores successfully" do
      params = HashWithIndifferentAccess.new({:cancerStudy => "brca_tcga_pub", 
                              :cancerAlteration => "brca_tcga_pub_mrna_merged_median_Zscores",
                              :cancerCaseList => "brca_tcga_pub_all",
                              :zThresh => "1.0",
                              :CNV_thresh => "1.0",
                              :genes => "PTTG1"})
      # warn params.inspect
    	scores = Cbio.getCbioScores(params)
    	# warn scores.inspect
    	(scores.has_key?("error") || scores.has_key?(:error)).should == false
    end

    it "gets cBio ME results successfully" do
      params = HashWithIndifferentAccess.new({:app => {:cancerStudy => "brca_tcga_pub"},
                              :zThresh => "1.0",
                              :CNV_thresh => "1.0",
                              :organism => "yeast",
                              :query => 'PDS1',
                              :deletions => 'CLB2',
                              :pValueThreshold => '0.05',
                              :ptenDown => 'false'})
      results = Cbio.queryCbioMutualExclusion(params)
      results.has_key?('table').should==true
      results.has_key?('error').should==false
      results['table'].scan(/\<tr\>/m).size.should > 5

      params = HashWithIndifferentAccess.new({:app => {:cancerStudy => "brca_tcga_pub"},
                              :zThresh => "1.0",
                              :CNV_thresh => "1.0",
                              :organism => "human",
                              :query => 'PDS1',
                              :deletions => 'CLB2',
                              :pValueThreshold => '0.05',
                              :ptenDown => 'false'})
      results = Cbio.queryCbioMutualExclusion(params)
      results.has_key?('table').should==true
      results.has_key?('error').should==false
      results['table'].scan(/\<tr\>/m).size.should < 2
    end

  end

end

