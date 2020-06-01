class ScreenTroll < ActiveRecord::Base
	def self.getScreenFileInfo()
		datasets = Hash.new{|hash, key| hash[key] = []}
		Dir.glob("#{Rails.root}/public/cgi-bin/screenTroll/screens/*.tab").each do |screenFile|
			file = File.new(screenFile, "r")
			description = file.gets
			for i in 0..1 # read first 2 lines
				 datasets["#{description}"] << file.gets
			end
		end
		Dir.glob("#{Rails.root}/public/cgi-bin/screenTroll/screens/competition/*.tab").each do |screenFile|
			file = File.new(screenFile, "r")
			description = file.gets
			for i in 0..1 # read first 2 lines
				 datasets["#{description}"] << file.gets
			end
		end
		Dir.glob("#{Rails.root}/public/cgi-bin/screenTroll/screens/costanzo/*.tab").each do |screenFile|
			file = File.new(screenFile, "r")
			description = file.gets
			for i in 0..1 # read first 2 lines
				 datasets["#{description}"] << file.gets
			end
		end
		return datasets
	end
end