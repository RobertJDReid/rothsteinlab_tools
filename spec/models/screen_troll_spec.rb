require 'spec_helper'

describe ScreenTroll do
	it "gets getScreenFileInfo just fine" do
		result = ScreenTroll.getScreenFileInfo()
		result.size.should > 1000
	end
end
