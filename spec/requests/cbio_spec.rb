require 'spec_helper'

describe "cbio scores test" do
	it "Loads cancer studies okay" do
		log_in_labMember();
		# save_and_open_page
		visit cbio_scores_path
		page.has_select?('app[cancerStudy]').should == true
		page.has_select?('app[cancerStudy]', :with_options => ['Breast Invasive Carcinoma (TCGA, Provisional)']).should == true
	end
end

describe "cbio ME test" do
	# Capybara.app_host = nil
	# a user is created in log_in_labMember(), for that user to be 
	# available for the rest of the test, use_transactional_fixtures must
	# be set to false. However, this causes the users that was created
	# in log_in_labMember() to not be deleted, therefore at the end of 
	# this test I run User.delete_all
	self.use_transactional_fixtures = false 
	it "Loads cancer studies okay", js: true do
		log_in_labMember();
		Capybara.default_wait_time = 30
		# skip_before_filter :authorize
		visit cbio_mutual_exclusion_path
		page.has_select?('app[cancerStudy]').should == true
		page.has_select?('app[cancerStudy]', :with_options => ['Breast Invasive Carcinoma (TCGA, Provisional)']).should == true
		select "Breast Invasive Carcinoma (TCGA, Provisional)", :from => "app[cancerStudy]"
		fill_in('query', :with => 'pds1')
		fill_in('deletions', :with => 'clb2')
		page.should have_content('valid gene')
		find('#submitForm').click
		page.should have_content('brca_tcga_gistic')
		User.delete_all
	end
	
end
