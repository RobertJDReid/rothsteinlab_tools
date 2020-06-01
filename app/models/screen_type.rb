class ScreenType < ActiveRecord::Base
	validates_presence_of  :screen_type
	validates_uniqueness_of :screen_type
end