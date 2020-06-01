class UsersController < ApplicationController

  # view --> display form to create new user
  def new
    @title="New User Registration"
    @header="<h1>New User Registration</h1><em>Fill out the form below to register.</em>"
    @user = User.new
  end

  # action --> create a new user
  def create
    @user=User.new(user_params)
    if [@user.valid?, verify_recaptcha(@user)].all? && @user.save
      @user.set_auth_token
      cookies[:auth_token] = @user.auth_token
      redirect_to root_url, notice: "Signed up!"
    else
      flash[:recaptcha_error]=nil
      @title="New User Registration"
      @header="<h1>New User Registration</h1><em>Fill out the form below to register.</em>"
      render "new"
    end
  end

  #  action --> update user creds
  def update
    @user = current_user
    user = current_user
    if (params[:user][:current_password].present?  && params[:user][:password].present?)
      user = false if(! User.authenticate(current_user.login, params[:user][:current_password]))
    end
    if(user && user.update_attributes(user_params))
      redirect_to root_url, :notice => "Your credentials have been updated."
    else
     # @user = current_user
      flash.now[:error] = "Incorrect Current Password" unless user
      @title="Email Password"
      @header="<h1>Email Password</h1><em>Enter your email address to have a new password sent to you.</em>"
      render "edit"
      #redirect_to :edit, :flash => { :error => "Error! Login and Email NOT Changed."}
    end
  end

  # view --> display form to request a password reset
  def forgot_password
    @title="Email Password"
    @header="<h1>Email Password</h1><em>Enter your email address to have a new password sent to you.</em>"
  end

  # action --> send password reset email
  def reset_password_request
    user = User.find_by_email(params[:user][:email])
    if(user)
      # add  recaptcha check here?
      user.send_password_reset
      redirect_to root_url, :notice => "Email sent with password reset instructions."
    else
      flash[:error] = "Could not send password.  Perhaps you entered you email address incorrectly."
      redirect_to root_url
    end
  end

  def edit
    @title="Change Personal Information"
    @header="<h1>Change Personal Information</h1><em>Enter new information below.</em>"
    @user=current_user
  end

  def welcome
    @title="Welcome to the Rothstein Lab Tool Suite"
    @header="<h1>Welcome to the Rothstein Lab Tool Suite</h1><em>To get started select an option from the menu above.</em>"
    respond_to do |format|
      format.html
    end
  end

  private

  def user_params
    params.require(:user).permit(:login, :password, :password_confirmation, :email)
  end

  def user_update_params
    params.require(:user).permit(:login, :password, :password_confirmation, :email,:current_password)
  end

end
