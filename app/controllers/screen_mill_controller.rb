class ScreenMillController < ApplicationController

	def dr_engine_setup
	  @title="ScreenMill - Data Review Engine"
	  @bg_image ="/tools/images/rotorimage.gif"
	  @header="<h1><i>ScreenMill - <b>D</b>ata <b>R</b>eview Engine</i></h1>"
	end
	
	def dr_engine
	  @title="DR Engine - Page 1"
	  @header="<h1><i>Data Review Engine</i></h1><em>Please select the colonies below that you would like to exclude from statistical consideration.</em>"
	  @page_num=params[:page_num] || 1
	  @params = params
	  if(@page_num != 'FIRST_PAGE')
	    unless(@page_num || @page_num.is_a?(Integer))
	      @page_num=1
	    end
	  end
	  if(params[:reset])
	    @resetting="true"
	  end      
	end
	
	def dr_results
	  @title="ScreenMill - Data Review Engine Results"
	  @bg_image ="/tools/images/rotorimage.gif"
	  @header="<h1><i>Data Review Engine Results</i></h1><em>All files may be opened with Microsoft Excel.</em>"
	  @stats=params[:stats]
	  @date=params[:date]
	  @GO_enrich = params[:enrichedGO]
	  if(params[:id_col] && params[:id_col].downcase == 'orf')
			if(@GO_enrich.blank?)
			  @GO_enrich << "<table class='borders'><tr><th>Query</th><th>Condition</th><th>P-Value</th><th>Aspect</th><th>GO Term</th><th>Under or Over Represented</th></tr><tr><td colspan='6'>No enrichment</td></tr></table>"
		  end
	  else
	    if(!@GO_enrich)
	      @GO_enrich=""
	    end
	    @GO_enrich << "<table class='borders'><tr><th>Query</th><th>Condition</th><th>P-Value</th><th>Aspect</th><th>GO Term</th><th>Under or Over Represented</th></tr><tr><td colspan='6'>GO enrichment not performed.</td></tr></table>"
	  end
	  # strip out /screen_mill/public
	  @sessionID=params[:sessionID]
	end


	def sv_engine_setup
	  @title="ScreenMill - Screen Visualization Engine"
	  @header="<h1><i>ScreenMill - Screen Visualization Engine</i></h1><em>A tool to visually compare data.</em>"
	end
	
	def sv_engine
	  @title="ScreenMill - Screen Visualization Engine"
	  @header="<h1><i>ScreenMill - Screen Visualization Engine</i></h1><em>A tool to visually compare data.</em>"
	end
	
	def key_file_info
	  @title="Key File Format Information"
	  @header="<h1>Key File Format Information</h1><em>Please follow the formating outlined below to ensure smooth operation.</em>"
	end

	def log_file_info
	  @title="Log File Format Information"
	  @header="<h1>Log File Format Information</h1><em>Please follow the formating outlined below to ensure smooth operation.</em>"
	end

	
	def cm_engine
	  @title="ScreenMill - CM Engine"
	  @header="<h1><i>ScreenMill - Colony Measurement Engine</i></h1><em>A tool quantify colony sizes.</em>"
	end
	
	def cm_engine_names
	  @title="CM Engine Naming Conventions"
	  @header="<h1>CM Engine Naming Conventions</h1><em>Please follow the naming convention outlined below to ensure smooth operation.</em>"
	end

	def download
	  # params[:mod] should be 'sv' or 'dr'. params[:id] should be an integer
	  if(request.env['HTTP_REFERER'] =~ /sv_engine$/)
	    params[:mod]="sv"
	  elsif(params[:mod] != 'dr' || params[:id] !~ /^[0-9]+$/)
	  	render :text=>"Error downloading #{params[:mod]} #{params[:f]}.<br>Could not locate file for download, please try again or contact the administrator."
	  end
		dir2= "/data/user_data/#{params[:mod]}/user_directory/#{current_user.id}/#{params[:id]}/#{params[:f]}"
		dir1 = File::expand_path Rails.root
		if File.file?(File.join(dir1, dir2))
			send_file File.join(dir1, dir2), :type=>MIME::Types.type_for(params[:f]).to_s
		elsif(request.env['HTTP_REFERER'] =~ /sv_engine/)
			#flash[:error]= "Error downloading #{params[:f]}.<br>Could not locate file for download, please try again or contact the administrator."
			redirect_to :action=>'sv_engine'
		else
			render :text=>"Error downloading #{params[:mod]} #{params[:f]}.<br>Could not locate file for download, please try again or contact the administrator."
		end
	end
end