# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      Rails.logger.info("Authentication: Found local user, signing in")
      sign_in_and_redirect(resource)
    else
      Rails.logger.info("Authentication: Not found a local user, trying LDAP")
      user = Ldap::Authenticator.new(
        email: params[:user][:email],
        password: params[:user][:password],
      ).authenticate

      if user
        sign_in_and_redirect(user)
      else
        set_flash_message!(:alert, :invalid)

        self.resource = resource_class.new(sign_in_params)
        clean_up_passwords(resource)
        respond_with_navigational(resource) { render :new, status: :unauthorized }
      end
    end
  end

  private

  def sign_in_and_redirect(resource)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end
end
