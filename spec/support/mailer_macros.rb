module MailerMacros
	def last_email
		# access last email sent in the ActionMailer::Base.deliveries array
		ActionMailer::Base.deliveries.last
	end

	def reset_email
		# clear emails
		ActionMailer::Base.deliveries = []
	end

end