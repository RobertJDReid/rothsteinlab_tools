require "spec_helper"

describe UserMailer do

  # check to make sure email is sent properly
  describe "password_reset" do
    let(:user) {FactoryGirl.create(:user, :password_reset_token => "anything") }
    let(:mail) { UserMailer.password_reset(user) }

    it "send user password reset url" do
      mail.subject.should eq("Password Reset")
      mail.to.should eq([user.email])
      mail.from.should eq(["admin@rothsteinlab.com"])
      mail.body.encoded.should match(edit_password_reset_path(user.password_reset_token))
    end
  end
end