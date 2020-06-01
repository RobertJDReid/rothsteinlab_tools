class FeatureRequests < ActiveRecord::Base
	def self.send_features(msg)
	  GeneralMailer.general_mail('admin@rothsteinlab.com', 'NEW FEATURE REQUEST...', msg).deliver
	end
end