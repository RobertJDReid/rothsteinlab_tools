require "spec_helper"

describe Permissions::AdminPermission do
  subject { Permissions.permission_for(FactoryGirl.build(:user, permissions: 'admin')) }
  it "allows anything" do
    should permit(:any, :thing)
    should permit_param(:any, :thing)
  end
end
