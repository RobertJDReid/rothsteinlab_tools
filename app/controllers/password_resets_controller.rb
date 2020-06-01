class PasswordResetsController < ApplicationController
  skip_before_filter :authorize

  def edit
    @title="Password Reset"
    @header="<h1>#{@title}</h1><em>Please enter a new password, below.</em>"
    @user = User.find_by_password_reset_token!(params[:id])
    if(!@user || @user.password_reset_sent_at.nil?)
      flash[:error] = "Invalid link!"
      redirect_to forgot_password_path
    elsif @user.password_reset_sent_at < 2.hours.ago
      flash[:error] = "Password reset has expired."
      redirect_to forgot_password_path
    end
  end
  
  def update
    @user = User.find_by_password_reset_token!(params[:id])
    params[:user][:password_reset_token] = nil
    if(!@user || @user.password_reset_sent_at.nil?)
      flash[:error] = "Invalid link!"
      redirect_to forgot_password_path
    elsif @user.password_reset_sent_at < 2.hours.ago
      flash[:error] = "Password reset has expired."
      redirect_to forgot_password_path
    elsif @user.update_attributes(reset_password_params)
      
      redirect_to root_url, :notice => "Password has been reset!"
    else
      @title="Password Reset"
      @header="<h1>#{@title}</h1><em>Please enter a new password, below.</em>"
      render :edit
    end
  end

  def reset_password_params
    params.require(:user).permit( :password, :password_confirmation, :password_reset_token)
  end

  
end
