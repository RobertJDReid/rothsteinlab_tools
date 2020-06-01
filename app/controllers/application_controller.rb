class ApplicationController < ActionController::Base
  layout "standard-layoutHorizontalMenuJQ"

  #  Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :authorize

  delegate :permit?, to: :current_permission
  helper_method :permit?

  delegate :permit_param?, to: :current_permission
  helper_method :permit_param?

 	private
 		def current_user
 			@current_user ||= User.find_by_auth_token!(cookies[:auth_token]) if cookies[:auth_token]
 		end
 		helper_method :current_user

 		def current_permission
 		  @current_permission ||= Permissions.permission_for(current_user)
 		end

    # redefine in other controllers to allow resources
    def current_resource
       nil
    end

	  def authorize
	    if current_permission.permit?(params[:controller], params[:action], current_resource)
        current_permission.permit_params! params
      else
        # warn "bad news bears"
        # warn current_permission.inspect
        if(current_user)
          redirect_to root_url, alert: "Not authorized. You do not have sufficient permissions to perform that action."
        else
        #   warn request.env.inspect
        #   warn "request path = #{request.env["ORIGINAL_FULLPATH"]}"
          session[:redirect_to] = request.env["ORIGINAL_FULLPATH"]
          redirect_to login_path, alert: "Not authorized. You must be logged in to perform that action. Login below."
        end
      end
	  end
end
