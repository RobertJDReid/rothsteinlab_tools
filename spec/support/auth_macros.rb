module AuthMacros
  def log_in(attributes = {})
    @_current_user = FactoryGirl.create(:user, attributes)
    visit login_path
    fill_in "Login", with: @_current_user.email
    fill_in "Password", with: FactoryGirl.attributes_for(:user)[:password]
    click_button "Log In"
    page.should have_content "Logged in"
  end

  def log_in_member(attributes = {})
    @_current_user = FactoryGirl.create(:user, permissions: 'standard') 
    visit login_path
    fill_in "Login", with: @_current_user.login
    # puts @_current_user.login
    # puts FactoryGirl.attributes_for(:user)[:password]
    fill_in "Password", with: FactoryGirl.attributes_for(:user)[:password]
    click_button "Log In"
    
    page.should have_content "Logged in"
  end

  def log_in_labMember(attributes = {})
    @_current_user = FactoryGirl.create(:user, permissions: 'labMember') 
    visit login_path
    fill_in "Login", with: @_current_user.login
    fill_in "Password", with: FactoryGirl.attributes_for(:user)[:password]
    click_button "Log In"
    page.should have_content "Logged in"
  end

  def log_in_admin(attributes = {})
    @_current_user = FactoryGirl.create(:user, permissions: 'admin') 
    visit login_path
    fill_in "Login", with: @_current_user.login
    fill_in "Password", with: FactoryGirl.attributes_for(:user)[:password]
    click_button "Log In"
    page.should have_content "Logged in"
    request.cookies[:auth_token] = @_current_user.auth_token
  end

  def current_user
    @_current_user
  end
end
