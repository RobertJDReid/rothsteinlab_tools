require 'spec_helper'

describe "NewFeatureRequest" do
	it "emails admin upon submission" do
		visit new_feature_request_path
		msg = "blah blah blah"
		fill_in "feature", :with => msg
		fill_in "email", :with => "tester@whatever.com"
		click_button "Submit"
		current_path.should eq(root_path)
		page.should have_content("Your request has been successfully submitted")
		last_email.body.should include(msg)
	end

end
 