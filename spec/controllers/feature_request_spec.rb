require 'spec_helper'
describe FeatureRequestsController do

  describe "GET new" do
    render_views
    it "emails displays error message if no content sent" do
      #post :create, {:feature => "blah"}
      post :create
      response.should render_template('new')
    end
  end
end
