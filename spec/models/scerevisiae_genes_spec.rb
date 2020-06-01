require 'spec_helper'

describe ScerevisiaeGene do
	it "validates valid gene" do
		result = ScerevisiaeGene.checkValidOrf('cln1')
		result.has_key?('orf').should == true
		result['orf'].should == 'YMR199W'
		result.has_key?('gene').should == true
		result['gene'].should == 'CLN1'
		

		# at the time of writing YBR013C does not have a gene name
		result = ScerevisiaeGene.checkValidOrf('YBR013C')
		result['gene'].should == ''
		result['orf'].should == 'YBR013C'

		result = ScerevisiaeGene.checkValidOrf('YDR103W')
		result['gene'].should == 'STE5'
		result['orf'].should == 'YDR103W'

	end

	it 'does not validate invalid name' do
		result = ScerevisiaeGene.checkValidOrf('YBR0133W')
		result.has_key?('error').should == true
		result = ScerevisiaeGene.checkValidOrf('foo1')
		result.has_key?('error').should == true
	end

end