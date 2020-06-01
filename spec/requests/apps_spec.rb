require 'spec_helper'

describe "ORF Converter Tests" do
	it "visits gene ID converter, receives error with no content", js: true do
		visit apps_orf_converter_path
		# fill_in('ids', :with => 'cln1 cln2 ydr113c sdfsdf')
		find('#submitConversion').click
		# save_and_open_page
		page.should have_content("You must type or paste in an identifier list to continue")
	end

	it "visits gene ID converter, fills in orf, gets proper gene name and description back", js: true do
		visit apps_orf_converter_path
		fill_in('ids', :with => 'cln2')
		find('#submitConversion').click
		find('#result1').find('table').should have_content("YPL256C")
	end

	it "visits gene ID converter, fills in gene, gets proper ORF", js: true do
		visit apps_orf_converter_path
		fill_in('ids', :with => 'YCR002C')
		find('#submitConversion').click
		# save_and_open_page
		find('#result1').find('table').should have_content("CDC10")
	end

	it "visits gene ID converter, fills in foo, gets no results", js: true do
		visit apps_orf_converter_path
		fill_in('ids', :with => 'xdvd')
		find('#submitConversion').click
		find('#result1').find('table').should have_content("n/a")
		find('#result1').should have_content('The following IDs could not be identified')
	end

	it "visits gene ID converter, fills in some genes, successfully pushes data into screenTroll", js: true do
		visit apps_orf_converter_path
		fill_in('ids', :with => 'bub1 bub2 mad1 mad2 mad3')
		find('#submitConversion').click
		find('#result1').find('#pushtoST').click
		find('#result2').should have_content('Excel')
		find('#result2').find('table').should have_content('Synthetic Sick/Lethal with kinetochore mutants')
	end
end


describe "Dissection reader test" do
	it "loads page alright" do
		visit apps_dissection_reader_path
		page.should have_content('The Dissection Reader software is GPL licensed and available on SourceForge here')
	end
end


describe "Site directed mutant test" do

	# it "fill in nothing get alert error", js: true do
	# 	visit apps_aa_mutator_path
	# 	find('#genPerms').click
	# 	page.should have_content('?')
	# end

	it "loads page alright, fills form, returns results", js: true do
		visit apps_aa_mutator_path
		fill_in('sequence', :with => 'ctgggcacttccaat')
		find('#subSeq').click
		find('#genPerms').click
		# this script takes a while to run
		Capybara.default_wait_time = 60
		# save_and_open_page
		# print page.html
		# 
		page.should have_content('HindI')
	end
end

describe "data intersection test" do
	it "fill in nothing, get alert error", js: true do
		visit apps_data_intersection_path
		find('input[type=submit]').click
		# save_and_open_page
		# save_and_open_page
		page.should have_content('You MUST have at least 2 datasets entered for comparison')
	end

	it "fills in 2 datasets, gets overlap", js: true do
		visit apps_data_intersection_path
		fill_in('area1', :with => "test1 test2 test3\ntest1 test test4")
		find('#submitData').click
		 # save_and_open_page
		find('#uniqueSet').should have_content('TEST2')
		find('#intersectionSet').should have_content('TEST1')
		find('#commonSet').should have_content('TEST1')
	end

	it "fills in 40 datasets, gets overlap", js: true do
		visit apps_data_intersection_path
		fill_in('area1', :with => "sdf\nsd\ndf\nb\nh\netyr\nd\nc \ngbr\nvasc\nvasc\n \n \n trey\n hw5e\n rf\n v\n bfsg \n trtkbvadsck kv \n vker\n kavkadv \n adgl kelck  lrgkw alckkq\n a w\n efk ado\n vkwrt\n on3h42qfe\n ack\n oxcv ksfog ,e6oyt4qowfemc fvw\n eo5\n evokd ok6y\n o4kgfva\n f vkwot\n hkbo\n vfamd so\n XZ,xo	qwdo1r o\n k6o\n bmo\n  mowe d\n  moor\n  go\n   qeor\n   g, eq\n   vo mco\n   wEM")
		find('#submitData').click
		# save_and_open_page
		find('#uniqueSet').should have_content('SDF')
		find('#intersectionSet').should have_content('VASC')
		find('#commonSet').should have_content('VASC')
	end

	it "fills >50 datasets, gets error", js: true do
		visit apps_data_intersection_path
		fill_in('area1', :with => "sdf\nsd\ndf\nb\nh\netyr\nd\nc \ngbr\nvasc\nvasc\ntrey\n hw5e\n rf\n v\n bfsg \n trtkbvadsck kv \n sdf\nsd\ndf\nb\nh\netyr\nd\nc \ngbr\nvasc\nvasc\ntrey\n hw5e\n rf\n v\n bfsg \n trtkbvadsck kv \n vker\n kavkadv \n adgl kelck  lrgkw alckkq\n a w\n efk ado\n vkwrt\n on3h42qfe\n ack\n oxcv ksfog ,e6oyt4qowfemc fvw\n eo5\n evokd ok6y\n o4kgfva\n f vkwot\n hkbo\n vfamd so\n XZ,xo	qwdo1r o")
		find('#submitData').click
		page.should have_content('You have entered more then 50 datasets.')
	end

end

describe "hyper geo test - submits to perl script." do
	it "fill in nothing, get alert error", js: true do
		visit apps_hyper_geometric_calculator_path
		find('#calcHG_submit').click
		page.should have_content('This field is required')
	end

	it "fill in improper values (tg > t), get error", js: true do
		visit apps_hyper_geometric_calculator_path
		fill_in('t', :with => '100')
		fill_in('tg', :with => '110')
		fill_in('tp', :with => '10')
		fill_in('gp', :with => '1')
		find('#calcHG_submit').click
		page.should have_content("'Population size' must be > 'successes in population'")
	end

	it "fill in improper values (tp > t), get error", js: true do
		visit apps_hyper_geometric_calculator_path
		fill_in('t', :with => '100')
		fill_in('tg', :with => '50')
		fill_in('tp', :with => '110')
		fill_in('gp', :with => '1')
		find('#calcHG_submit').click
		page.should have_content("'Population size' must be > 'sample size'")
	end

	it "fill in improper values (gp > tp), get error", js: true do
		visit apps_hyper_geometric_calculator_path
		fill_in('t', :with => '100')
		fill_in('tg', :with => '50')
		fill_in('tp', :with => '50')
		fill_in('gp', :with => '51')
		find('#calcHG_submit').click
		page.should have_content("'Successes in population' must be > 'successes in sample'")
	end

	it "fill in proper values, get over-represented p-value", js: true do
		visit apps_hyper_geometric_calculator_path
		fill_in('t', :with => '100')
		fill_in('tg', :with => '50')
		fill_in('tp', :with => '35')
		fill_in('gp', :with => '30')
		find('#calcHG_submit').click
		page.should have_content("over-represented")
	end

	it "fill in proper values, get under-represented p-value", js: true do
		visit apps_hyper_geometric_calculator_path
		fill_in('t', :with => '100')
		fill_in('tg', :with => '50')
		fill_in('tp', :with => '35')
		fill_in('gp', :with => '5')
		find('#calcHG_submit').click
		page.should have_content("under-represented")
	end
end

describe "CDF test" do
	it "visits CDF, generate graph, add subset", js: true do
		Capybara.default_wait_time = 30
		visit apps_generate_CDF_path
		expect(page).not_to have_errors
		find('#generateCDFbtn').click
		page.should have_css('svg path')
		find('#addToCDFbtn').click
		click_button('addToCDFbtn')
		expect(page).not_to have_errors
		page.should have_css('svg .legend')

		# save_and_open_page
		fill_in('term',:with => 'damage')

		
		page.should have_css('svg .na')

		page.should have_content('DNA damage checkpoint')
		first('button.term').click
		page.should have_css('svg .na')
	end
end
