require 'spec_helper'

describe "excluded_colonies/show" do
  before(:each) do
    @excluded_colony = assign(:excluded_colony, stub_model(ExcludedColony,
      :experiment => nil,
      :experiment_raw_dataset => nil,
      :row => 1,
      :column => "Column"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(/1/)
    rendered.should match(/Column/)
  end
end
