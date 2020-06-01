require 'spec_helper'

describe User do
  describe "#send_password_reset" do
    # assign the user to a factory user before the specs are run
    let(:user) {FactoryGirl.create(:user)}

    it "generates a unique password_reset_token each time" do
      user.send_password_reset
      last_token = user.password_reset_token
      user.send_password_reset
      user.password_reset_token.should_not eq(last_token)
    end

    it "saves the time the password reset was sent" do   
      Timecop.freeze
      
      user.send_password_reset
      time = user.reload.password_reset_sent_at

      #  there was a problem comparing the times directy (ie without to_i, i fixed it according
      #  to this recomendation
      #  http://blog.tddium.com/2011/08/07/rails-time-comparisons-devil-details-etc/
      expect(time.to_i).to eq(Time.zone.now.to_i)
      # user.reload.password_reset_sent_at.should eq(Time.zone.now)
    end

    it "delivers email to user" do
      user.send_password_reset
      last_email.to.should include(user.email)
    end
  end
end