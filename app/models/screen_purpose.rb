class ScreenPurpose < ActiveRecord::Base
	validates_presence_of  :purpose
	validates_uniqueness_of :purpose
end