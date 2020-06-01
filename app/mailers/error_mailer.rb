class ErrorMailer < ActionMailer::Base
  default from: "noreply@rothsteinlab.com"
  def error_mail(to, subject, msg)
    @msg = msg
    mail to: to, subject: subject
  end
end