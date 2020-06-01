class ScreenTrollController < ApplicationController

	def screenTroll
	  @title="ScreenTroll"
	  @header="<h1><i>#{@title}</i></h1><em>A comparison tool for Saccharomyces cerevisiae screens.</em>"
	end

	def stats
	  @title="ScreenTroll Statistics"
	  @header="<h1><i>#{@title}</i></h1><em>An explanation of what goes on 'under the hood'.</em>"
	end

	def list
	  @title="ScreenTroll Screens"
	  @header="<h1><i>#{@title}</i></h1><em>A list of the screens in ScreenTroll.</em>"
	  @dataList = ScreenTroll.getScreenFileInfo()
	end

	def externalToolList
	  @title="External Tool List"
	  @header="<h1><i>#{@title}</i></h1><em>Links to other useful tools for the scientific community.</em>"
	end

	def submission
	  @title="ScreenTroll Data Submission"
	  @header="<h1><i>#{@title}</i></h1><em> - submit data to help give more statistical power to ScreenTroll!</em>"
	end

end
