class SessionsController < ApplicationController

  def new
    @title="User Login"
    @header="<h1>User Login</h1><em>Please enter your login and password below and then click the submit button.</em>"
  end

  def create
	  user = User.find_by_login(params[:user][:login])
    # puts params.inspect
    # all = User.all()
    # logger.debug("user = #{user.inspect}")
    # warn "user = #{user.inspect}"
    # warn "all = #{all.inspect}"
    # warn "params = #{params.inspect}"
    # logger.debug("all = #{all.inspect}")
    # logger.debug("params = #{params.inspect}")
    # puts 'something'
    # warn User.authenticate(user.login, params[:user][:password])
    # warn params.inspect
	  if (user && User.authenticate(user.login, params[:user][:password]))
      user.set_auth_token
	  	if params[:remember_me]
        cookies.permanent[:auth_token] = user.auth_token
      else
        cookies[:auth_token] = user.auth_token
      end
      if(session[:redirect_to].present?)
        temp = session[:redirect_to]
        session[:redirect_to]=nil
        session.delete(:redirect_to)
        redirect_to temp, notice: "Logged in!"
      else
        redirect_to root_url, notice: "Logged in!"
      end
	  else
      @title="User Login"
      @header="<h1>User Login</h1><em>Please enter your login and password below and then click the submit button.</em>"
	    flash[:error] = "Login Unsuccessful."
      render "new"
	  end
  end

  def destroy
    session[:user] = nil
    cookies.delete(:auth_token)
    redirect_to root_path, notice:"Logged Out."
  end

end
