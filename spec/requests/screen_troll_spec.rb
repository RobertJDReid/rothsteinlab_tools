require 'spec_helper'

describe "Screen Troll test" do

	it "submits nothing, returns error", js: true do
		visit screenTroll_path
		find('input[type=submit]').click
		# save_and_open_page
		page.should have_content("You must enter some data to analyze")
	end

	it "submits genes succesfully", js: true do
		visit screenTroll_path
		fill_in('orfs', :with => 'bub1 bub2 mad1 mad2 mad3')
		find('input[type=submit]').click
		within_frame 'results' do  
      page.should have_content("ScreenTroll Results")
			page.should have_content('Excel')
			page.find('table').should have_content('Synthetic Sick/Lethal with kinetochore mutants')
	  end
	end

	it "submits example genes succesfully", js: true do
		visit screenTroll_path
		find('#exampleLink').click
		page.should have_selector('#modalExampleDrag', visible: true)
		within_frame 'results' do  
      page.should have_content("ScreenTroll Results")
			page.should have_content('Excel')
			page.find('table').should have_content('Synthetic Sick/Lethal with kinetochore mutants')
	  end
	end
	
	# not sure how to properly test these
	# it "attempts to download screenTroll script" do
	# 	find('#dlScript').click
	# 	page.response_headers['Content-Type'].should eq "application/zip"?
	# end
	# 
	# it "attempts to download screenTroll datasets" do
	# 	find('#dlAllData').click
	# 	page.response_headers['Content-Type'].should eq "application/zip"?
	# end
	# 
	# it "submits genes succesfully, attempts to download excel file", js: true do
	# 	visit screenTroll_path
	# 	fill_in('orfs', :with => 'bub1 bub2 mad1 mad2 mad3')
	# 	find('input[type=submit]').click
	# 	within_frame 'results' do  
 #      find('.screenTrollResults').first('h2').find('span').click
	# 		page.response_headers['Content-Type'].should eq "application/pdf"
	#   end
	# end
	

end