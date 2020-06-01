class UserMailer < ActionMailer::Base
  default from: "admin@rothsteinlab.com"
  def password_reset(user)
    @password_url = edit_password_reset_url(user.password_reset_token)
    mail to: user.email, subject: "Password Reset"
  end
end
