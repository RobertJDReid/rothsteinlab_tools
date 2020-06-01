module ApplicationHelper

	def current_user_info
	  if current_user then
	    return "#{ link_to 'Logged in as: '+current_user.login+' '+current_user.permissions, edit_path } - #{ link_to 'Logout', logout_path }"
	  else
	    return "Not currently logged in. #{ link_to 'Login', login_path} | #{link_to 'Sign up', new_user_path}"
	  end
	end

	def errors_for_helper(model)
		html=''
		if (model).errors.any?
			html = '<div class="error" >'
			html << '<strong>The following errors occurred:</strong></br><br/><ul>'
			(model).errors.each do |field,msg|
				if(msg =~ /already exists/i)
					html << "<li>#{msg}</li>"
				else
					field = field.to_s.humanize
					html <<	"<li>#{field}: #{raw(msg)}</li>"
				end
			end
			html << '</ul></div>'
		 end
		 return raw(html)
	end

end
