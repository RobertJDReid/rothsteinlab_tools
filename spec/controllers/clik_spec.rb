require 'spec_helper'
describe AppsController do

  describe "GET clik" do
    # render_views #renders_views after controller is called
    it "assigns @versions" do
    	# note that this must be done as an admin since it is the only one
    	# that has request.cookies[:auth_token] = @_current_user.auth_token
      log_in_admin()
      get :clik
      # warn "v = #{assigns(:version)}, #{@version}, #{:version}"
      assigns(:version).should_not be_nil
    end
  end
end
