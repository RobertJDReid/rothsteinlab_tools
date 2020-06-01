require 'spec_helper'

describe "excluded_colonies/new" do
  before(:each) do
    assign(:excluded_colony, stub_model(ExcludedColony,
      :experiment => nil,
      :experiment_raw_dataset => nil,
      :row => 1,
      :column => "MyString"
    ).as_new_record)
  end

  it "renders new excluded_colony form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", excluded_colonies_path, "post" do
      assert_select "input#excluded_colony_experiment[name=?]", "excluded_colony[experiment]"
      assert_select "input#excluded_colony_experiment_raw_dataset[name=?]", "excluded_colony[experiment_raw_dataset]"
      assert_select "input#excluded_colony_row[name=?]", "excluded_colony[row]"
      assert_select "input#excluded_colony_column[name=?]", "excluded_colony[column]"
    end
  end
end
