require 'spec_helper'

describe App do
	describe "#getInteractionTypes" do
		it "gets yeast interaction types successfully" do
			results = App.getInteractionTypes()
			results.has_key?('Genetic').should == true
			results['Genetic'].size.should > 1
			results.has_key?('Physical').should == true
			results['Physical'].size.should > 1
			results = App.getInteractionTypes('Scerevisiae')
			results.has_key?('Genetic').should == true
			results['Genetic'].size.should > 1
			results.has_key?('Physical').should == true
			results['Physical'].size.should > 1
		end

		it "gets human interactions successfully" do
			results = App.getInteractionTypes('Hsapien')
			results.has_key?('Genetic').should == true
			results['Genetic'].size.should > 1
			results.has_key?('Physical').should == true
			results['Physical'].size.should > 1
		end

		it "gets pombe interactions successfully" do
			results = App.getInteractionTypes('Spombe')
			results.has_key?('Genetic').should == true
			results['Genetic'].size.should > 1
			results.has_key?('Physical').should == true
			results['Physical'].size.should > 1
		end

		it "gets displays error if unknown organism" do
			results = App.getInteractionTypes('unknown')
			results.has_key?(:error).should == true
		end
	end

	describe "#getBioGridVersion" do
		it "successfully pulls biogrid version" do
			 result = App.getBioGridVersion()
			 result.should_not == 'n/a'
			 result.should_not == ''
		end
	end

	describe "#findGOtermOrComplex" do
		it "successfully pulls GO term" do
			result = App.findGOtermOrComplex('DNA damage checkpoint')
			result.has_key?('GO').should == true
			result['GO'].size.should > 0
			result = App.findGOtermOrComplex('GO:0000011')
			result.has_key?('GO').should == true
			result['GO'].size.should == 1
			result['GO'][0]['genes'].size.should >10
		end

		it "successfully pulls complex info" do
			result = App.findGOtermOrComplex('anaphase-promoting')
			result.has_key?('COMPLEX').should == true
			result['COMPLEX'].size.should > 0
			result['COMPLEX'][0]['genes'].size.should >10
		end

		it "returns empty arrays if it cannot find data" do
			result = App.findGOtermOrComplex('fooBarfoobar')
			result['COMPLEX'].size.should == 0
			result['GO'].size.should == 0
		end
	end

	describe "#getDatasetOverlaps" do
		# this is tested in requests/app
	end

	describe "#checkValidGenes" do
		it "validates good genes" do
			results = App.checkValidGenes({:organism=>'yeast',:genes=>['cln1', 'cdc28', 'STB5', 'foobar', 'YBR013C', 'YDR103W', 'YBR0133W']})
			results['goodGenes'].size.should == 6
			results['goodGenes']['_size'].should == 5
			results['badGenes'].size.should == 2
			results = App.checkValidGenes({:organism=>'human',:genes=>['cln1', 'cdc28', 'STB5', 'foobar', 'YBR013C', 'YDR103W', 'YBR0133W']})
			results['goodGenes'].size.should == 1
			results['goodGenes']['_size'].should == 0
	
			results['badGenes'].size.should == 7
			results = App.checkValidGenes({:organism=>'human',:genes=>[]})
			results['goodGenes'].size.should == 0
			results['badGenes'].size.should == 0
			results = App.checkValidGenes({})
			results['goodGenes'].size.should == 0
			results['badGenes'].size.should == 0

			results = App.checkValidGenes({:organism=>'human',:genes=>['PTTG1', 'PTEN', "RB1", 'foobar']})
			results['goodGenes'].size.should == 4
			results['goodGenes']['_size'].should == 3
			results['badGenes'].size.should == 1
		end
	end

	describe "#checkForHumanOrthologs" do
		it "check for human orthologs given yeast genes" do
			result = App.checkForHumanOrthologs()
			result.size.should == 0
			params = HashWithIndifferentAccess.new({'cln1'=>1,'cln2'=>1,'clb2'=>1,'npl3'=>1,'act1'=>1})
			result = App.checkForHumanOrthologs(params)
			result.size.should == 0
			genes = App.checkValidGenes({:organism=>'yeast',:genes=>['cln1','cln2','clb2','npl3','act1']})
			result = App.checkForHumanOrthologs(genes['goodGenes'])
			result.size.should > 10
		end
	end
end

