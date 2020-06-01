class FeatureRequestsController < ApplicationController
  def new
    @data={:feature=>'', :email=>''}
    @title="Rothstein Lab - Feature Request"
    @header="<h1>#{@title}</h1><em>Want a feature to be added? Request it using the form below.</em>"
  end

  def create
    @title="Rothstein Lab - Feature Request"
    @header="<h1>#{@title}</h1><em>Want a feature to be added? Request it using the form below.</em>"
    @data=params
    if(!params[:feature].present?)
      flash[:error] = "Error! Feature request message cannot be blank."
      render :new
    elsif(verify_recaptcha(params))
      if(FeatureRequests.send_features("#{@data[:feature]} \n\nEmail Address:\n'#{@data[:email]}'"))
        redirect_to root_url, :notice => "Your request has been successfully submitted. Thank you."
      else
        flash[:error] = "Error! Could not send feature request. Please try again later."
        render :new
      end
    else
      flash[:recaptcha_error]=nil
      flash[:error] = "Error! Failed human test. Please try again."
      render :new
    end
  end
end