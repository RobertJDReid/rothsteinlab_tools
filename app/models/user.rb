require 'digest/sha1'

class User < ActiveRecord::Base
  validates_presence_of      :password,
                             if:       :password_required?,
                             message:  "Password cannot be blank"

  validates_length_of        :password,
                             within:    5..40,
                             if:        :custom?,
                             message:   "Password must be between 5 and 40 characters"

  validates_presence_of      :password_confirmation,
                             if:       :custom?,
                             message:  "Password confirmation cannot be blank"

  validates_confirmation_of  :password,
                             if:       :custom?,
                             message:  "Passwords don't match!"

  validates_presence_of :login, message:  "Login cannot be blank"

  validates_length_of :login,
                      within:   3..40,
                      message:  "Login must be between 5 and 40 characters",
                      if:       lambda{ login.present? }

  validates_presence_of  :email, message:  "Email cannot be blank"

  validates_uniqueness_of :login, message:  "That name already exists"

  validates_uniqueness_of :email, message:  "That email address already exists"

  validates_format_of :email,
                      with:     /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i,
                      message:  "Invalid email address",
                      if:       lambda{ email.present? }


  attr_accessor :password, :password_confirmation

  before_create { generate_token(:auth_token) }

  before_save :encrypt_password
  after_save :clear_password

  def self.authenticate(login,pass)
    u=find_by_login(login)
    return nil if u.nil?
    if User.encrypt(pass, u.salt)==u.hashed_password
     # warn "authenticated"
      return true
    end
    #warn "not auth"
    nil
  end

  def set_auth_token
    if(!self.has_attribute?(:auth_token) || !self.auth_token.present?)
      self.auth_token = SecureRandom.urlsafe_base64
      self.update_attribute(:auth_token, self.auth_token)
    end
  end

  def send_password_reset
    generate_token(:password_reset_token)
    update_attribute(:password_reset_token, self.password_reset_token)
    self.password_reset_sent_at = Time.zone.now
    update_attribute(:password_reset_sent_at, self.password_reset_sent_at)
    UserMailer.password_reset(self).deliver
  end


  def encrypt_password
    if password.present?
      self.salt = SecureRandom.urlsafe_base64 if !salt?
      self.hashed_password = User.encrypt(password, salt)
    end
  end

  def generate_token(column)
   begin
     self[column] = SecureRandom.urlsafe_base64
   end while User.exists?(column => self[column])
  end


  def clear_password
    self.password = nil
  end

  protected

  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass+salt)
  end

  def  password_required?
    # warn !password.blank?
    # warn !hashed_password.present?
    # warn !hashed_password.present?  ||  !password.blank?
    !hashed_password.present?  ||  !password.blank?
  end

  def no_errors?
    return errors.blank?
  end

  def custom?
    # warn password_required?
    # warn no_errors?
    # warn password_required? && no_errors?
    return password_required? && no_errors?
  end
end
