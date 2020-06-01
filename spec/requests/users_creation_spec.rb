require 'spec_helper'


# describe "User Creation" do
# 	it "cannot modify permissions as member" do
# 	  user = FactoryGirl.create(:user, permissions: 'member', login: 'tester', password: "secret", password_confirmation: "secret", email: "test@tesdsdsdst.com")
# 	  post sessions_path, login: user.login, password: "secret"
# 	  post edit_path, email: user.email, login: user.login, permissions: 'admin'

# 	  modUser = User.last
# 	  modUser.login.should eq("tester")
# 	  modUser.permissions.should_not eq("admin")
# 	end

#end