require 'spec_helper'

describe "excluded_colonies/index" do
  before(:each) do
    assign(:excluded_colonies, [
      stub_model(ExcludedColony,
        :experiment => nil,
        :experiment_raw_dataset => nil,
        :row => 1,
        :column => "Column"
      ),
      stub_model(ExcludedColony,
        :experiment => nil,
        :experiment_raw_dataset => nil,
        :row => 1,
        :column => "Column"
      )
    ])
  end

  it "renders a list of excluded_colonies" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => "Column".to_s, :count => 2
  end
end
