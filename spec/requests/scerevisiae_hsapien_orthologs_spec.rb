
require 'spec_helper'

describe "search test" do
	it "checks links" do
		visit scerevisiae_hsapien_orthologs_search_path
		page.should_not have_content('Create a new ortholog pair')
		page.should_not have_content('Submit a new ortholog pair')
	end

	it "fill in gobibty gook, get back no orthologs", js: true do
		visit scerevisiae_hsapien_orthologs_search_path
		fill_in('genes', :with => 'sdoiufi23weopo23-0')
		find('#submitForm').click
		page.should have_content("Could not find orthologs for the ")	
	end

	it "fill human and yeast genes, get back results", js: true do
		visit scerevisiae_hsapien_orthologs_search_path
		fill_in('genes', :with => 'pttg1 npl3')
		find('#submitForm').click
		find('#results').find('#orthologs').should have_content("SRSF1")
		find('#results').find('#orthologs').should have_content("PDS1")
	end

	it "sign in as user, can navigate to submit new ortholog" do
		log_in_member();
		visit scerevisiae_hsapien_orthologs_search_path
		# save_and_open_page
		page.should_not have_content('Create a new ortholog pair')
		page.should have_content('Submit a new ortholog pair')
		find('#submitLink').click
		page.should have_content("Submit a new S. cerevisiae / human ortholog pair")
	end

	it "sign in as lab member, can navigate to create new ortholog" do
		log_in_labMember();
		visit scerevisiae_hsapien_orthologs_search_path
		page.should have_content('Create a new ortholog pair')
		page.should_not have_content('Submit a new ortholog pair')
		find('#createLink').click
		page.should have_content("Create a new Rothstein lab S. cerevisiae / human ortholog pair")
	end
end

describe "list test" do
	
	it "list all results", js: true do
		visit scerevisiae_hsapien_orthologs_path
		page.should have_content('Ensembl')
		page.should_not have_content('Create a new ortholog pair')
		page.should_not have_content('Submit a new ortholog pair')
	end

	self.use_transactional_fixtures = false
	it "sign in as user, can navigate to submit new ortholog", js: true do
		log_in_member();
		visit scerevisiae_hsapien_orthologs_path
		page.should_not have_content('Create a new ortholog pair')
		# save_and_open_page
		page.should have_content('Submit a new ortholog pair')
		find('#submitLink').click
		page.should have_content("Submit a new")
		# User.delete_all
	end

	it "sign in as lab member, can navigate to create new ortholog", js: true do
		log_in_labMember();
		visit scerevisiae_hsapien_orthologs_path
		page.should have_content('Create a new ortholog pair')
		page.should_not have_content('Submit a new ortholog pair')
		find('#createLink').click
		page.should have_content("Create a new")
		# User.delete_all
	end
	# self.use_transactional_fixtures = true
	after :each do
	  User.delete_all
	end
end


describe "creates a new ortholog" do
	
	self.use_transactional_fixtures = false 

	it "test ortholog fields with bad data", js: true do
		log_in_labMember()
		visit new_scerevisiae_hsapien_ortholog_path
		fill_in("scerevisiae_hsapien_ortholog_humanGeneName", with: "Foobar")
		find('#submitButton').click
		page.should have_content("Invalid human gene name")
		find('#scerevisiae_hsapien_ortholog_humanEnsemblID').value.should eq '?'
		fill_in("tempYeast", with: "foo")
		find('#submitButton').click
		page.should have_content("Invalid yeast ORF")
	end

	it "test ortholog fields with good data", js: true do
		log_in_labMember()
		visit new_scerevisiae_hsapien_ortholog_path
		fill_in("scerevisiae_hsapien_ortholog_humanGeneName", with: "PTTG1")
		find('#submitButton').click
		fill_in("tempYeast", with: "cln1") 
		find('#submitButton').click

		page.execute_script('$("#scerevisiae_hsapien_ortholog_humanGeneName").valid();')
		page.execute_script('$("#tempYeast").valid();')

		fill_in("scerevisiae_hsapien_ortholog_homologyType", with: "foo")
		find('#submitButton').click
		# page.should have_content("Valid")
		page.should have_content("This field is required")
		fill_in("scerevisiae_hsapien_ortholog_source", with: "foo")
		find('#submitButton').click

		# find('#yeastOrf').set 'YMR199W'
		# 
		# since the humanEnsembl id field is locked, its value cannot be set here and this test fails...
		# find('#scerevisiae_hsapien_ortholog_humanEnsemblID').set 'ENSG00000164611'
		# find('#submitButton').click
		# save_and_open_page
		page.should have_content("created successfully")
	end

	after :all do
	  User.delete_all
	  ScerevisiaeHsapienOrtholog.where(:source=>'foo').destroy_all
	end
end


describe "edit test" do
	it "tries to edit a ortholog pair as guest and is denied" do
		visit edit_scerevisiae_hsapien_ortholog_path(100)
		page.should have_content('Not authorized')
	end

	it "tries to edit a ortholog pair as a member and is denied" do
		log_in_member()
		visit edit_scerevisiae_hsapien_ortholog_path(100)
		page.should have_content('Not authorized')
	end

	it "tries to edit a ortholog pair as a lab member and succeeds" do
		log_in_labMember()
		@ortholog = FactoryGirl.create(:scerevisiae_hsapien_ortholog)
		visit edit_scerevisiae_hsapien_ortholog_path(@ortholog.id)
		page.should have_content('Edit ortholog information')
		# warn find('#yeastOrf').value
		# page.should have_content('YFL039C')
		# yeastOrf is a hidden field that gets filled in by js
		find('#yeastOrf').set 'YFL039C'
		fill_in("scerevisiae_hsapien_ortholog_source", with: "35")
		find('#submitButton').click
		page.should have_content("was successfully updated")
	end

end

describe "submit test" do
	it "cannot submit new ortholog suggestion as guest" do
		visit scerevisiae_hsapien_ortholog_submit_path
		page.should have_content('Not authorized')
	end

	it "posts a new ortholog submission, successfully sends email notice" do
		ScerevisiaeHsapienOrtholog.where(:source=>'foo').destroy_all
		user = FactoryGirl.create(:user, permissions: 'standard') 
		post sessions_path, user:{login:user.login,password:'foobar'}

		post scerevisiae_hsapien_ortholog_new_pair_submission_path, scerevisiae_hsapien_ortholog:
			{humanGeneName:"PTTG1", humanEnsemblID:"ENSG00000164611", yeastOrf:"YMR199W", homologyType:"foo", 
			source:"foo", percentIdentityWithRespectToQueryGene:"", percentIdentityWithRespectToYeastGene:"",
			created_by:"test", updated_by:"test"}, 
			recaptcha_challenge_field:"03AHJ_Vuv6rpgWjBmMLK7Ebf=j", 
			recaptcha_response_field: "03AHJ_Vuv6rpgWjBmMLK7Ebf=j"
		last_email.body.should include('PTTG1')
		last_email.body.should include('MAKE SURE TO APPROVE THIS INTERACTION IN DATABASE IF IT IS VALID!')
		user.destroy!
	end

	self.use_transactional_fixtures = false 
	
	it "Attempts to submit new ortholog suggestion as member", js: true do
		
		log_in_member()
		
		visit scerevisiae_hsapien_ortholog_submit_path
		expect(page).not_to have_errors
		fill_in("scerevisiae_hsapien_ortholog_humanGeneName", with: "PTTG1")
		fill_in("tempYeast", with: "cln1") 
		
		
		find('#submitButton').click
		# should causes the page to 'wait' → this is required in order for the 
		page.should_not have_content("invalid")
		page.execute_script('$("#scerevisiae_hsapien_ortholog_humanGeneName").valid();')
		page.execute_script('$("#tempYeast").valid();')
		page.should have_content("Valid")


		find('#scerevisiae_hsapien_ortholog_humanEnsemblID').value.should_not eq '?'
		find('#scerevisiae_hsapien_ortholog_humanEnsemblID').value.should_not eq ''


		page.should_not have_content("Invalid yeast ORF")
		page.should have_content("This field is required")

		fill_in("scerevisiae_hsapien_ortholog_homologyType", with: "foo")
		find('#submitButton').click
		page.should have_content("This field is required")
		fill_in("scerevisiae_hsapien_ortholog_source", with: "foo")
		page.should have_content("Valid")
		find('#submitButton').click
		
		# save_and_open_page
		page.should have_content("successfully submitted. Submissions take ~24hrs to be approved before being added to the database")
		
		# this works sometimes, but not always.
		# last_email.body.should include('PTTG1')
		# last_email.body.should include('MAKE SURE TO APPROVE THIS INTERACTION IN DATABASE IF IT IS VALID')

	end

	after :all do
		User.delete_all
		ScerevisiaeHsapienOrtholog.where(:source=>'foo').destroy_all
	end
end