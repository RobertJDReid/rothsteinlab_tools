require 'spec_helper'

describe "ExcludedColonies" do
  describe "GET /excluded_colonies" do
    it "works! (now write some real specs)" do
      # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
      get excluded_colonies_path
      response.status.should be(200)
    end
  end
end
