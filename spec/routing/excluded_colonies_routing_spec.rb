require "spec_helper"

describe ExcludedColoniesController do
  describe "routing" do

    it "routes to #index" do
      get("/excluded_colonies").should route_to("excluded_colonies#index")
    end

    it "routes to #new" do
      get("/excluded_colonies/new").should route_to("excluded_colonies#new")
    end

    it "routes to #show" do
      get("/excluded_colonies/1").should route_to("excluded_colonies#show", :id => "1")
    end

    it "routes to #edit" do
      get("/excluded_colonies/1/edit").should route_to("excluded_colonies#edit", :id => "1")
    end

    it "routes to #create" do
      post("/excluded_colonies").should route_to("excluded_colonies#create")
    end

    it "routes to #update" do
      put("/excluded_colonies/1").should route_to("excluded_colonies#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/excluded_colonies/1").should route_to("excluded_colonies#destroy", :id => "1")
    end

  end
end
