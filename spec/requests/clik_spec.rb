require 'spec_helper'

describe "Apps::CLIK" do
	it "Hides BioGRID data when no version present" do
		log_in_member();
		visit clik_index_path
		page.should_not have_content("Not authorized")
		page.should have_content("BioGRID")
		page.should have_content("PrePPI")
		page.should have_selector("#interactions")
	end
end
