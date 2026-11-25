# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  def create
    self.resource = local_user

    if resource
      Rails.logger.info("Authentication: Found local user, signing in")
      sign_in_and_redirect(resource)
    else
      Rails.logger.info("Authentication: Not found a local user, trying LDAP")
      user = ldap_user

      if user
        sign_in_and_redirect(user)
      else
        set_flash_message!(:alert, :invalid, authentication_keys: resource_class.authentication_keys.join(", "))

        self.resource = resource_class.new(sign_in_params)
        clean_up_passwords(resource)
        respond_with_navigational(resource) { render :new, status: :unauthorized }
      end
    end
  end

  private

  # A user Devise refuses (User#active_for_authentication? false: a locked one) must get the same
  # answer as a wrong password, never the failure app's redirect, which would tell that the
  # password was right. Devise refuses by throw :warden from its after_set_user hook, after
  # logging the user out: caught here, it becomes "no local user".
  def local_user
    user = catch(:warden) { warden.authenticate(auth_options) }
    user if user.is_a?(resource_class)
  end

  def ldap_user
    user = Ldap::Authenticator.new(
      email: params[:user][:email],
      password: params[:user][:password],
    ).authenticate
    user if user&.active_for_authentication?
  end

  def sign_in_and_redirect(resource)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end
end
