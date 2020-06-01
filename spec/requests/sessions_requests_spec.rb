require 'spec_helper'

# we already are testing the creation of sessions via the tests in auth_macros.rb
# this spec will test if the user is redirected properly upon logging in.
describe "Session Creation" do
	it "Attempts to access restricted site, redirects to login page then back to restricted site" do
		visit clik_index_path
		current_path.should eq(login_path)
		user = FactoryGirl.create(:user, permissions: 'standard')
		fill_in "Login", with: user.login
		fill_in "Password", with: FactoryGirl.attributes_for(:user)[:password]
		click_button "Log In"
		page.should have_content "Logged in"

		# should redirect to clik path upon login
		current_path.should eq(clik_index_path)
	end

	it "Attempts normal login - should redirect back to root" do
		log_in_member()
		# should redirect to clik path upon login
		current_path.should eq(root_path)
	end
end