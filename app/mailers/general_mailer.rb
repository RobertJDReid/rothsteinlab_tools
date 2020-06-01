class GeneralMailer < ActionMailer::Base
  default from: "admin@rothsteinlab.com"
  def general_mail(to, subject, msg)
  	@msg = msg
    mail to: to, subject: subject
  end
end