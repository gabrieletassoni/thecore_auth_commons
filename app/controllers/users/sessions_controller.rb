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
        refuse_like_a_wrong_password
      end
    end
  end

  private

  # A user Devise refuses (User#active_for_authentication? false: a locked one) must get exactly
  # the wrong-password answer, never the failure app's 302, which would tell that the password was
  # right. Devise refuses by throw :warden from its after_set_user hook (after logging the user
  # out) wherever the user is first authenticated in this request: in create, in sign_in after
  # LDAP, or already in a host's before_action reading current_user (thecore_ui_commons <= 3.4.0
  # did, in reject_locked!),
  # since Devise lets the password strategy run on the form params for the whole sign-in request.
  # So the catch wraps the whole action, callbacks included.
  def process_action(*)
    return super unless action_name == "create"

    catch(:warden) { return super }
    refuse_like_a_wrong_password
  end

  def refuse_like_a_wrong_password
    # The form params must not authenticate anyone again while the page renders (current_user).
    request.env["devise.allow_params_authentication"] = false
    set_flash_message!(:alert, :invalid, authentication_keys: resource_class.authentication_keys.join(", "))

    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    respond_with_navigational(resource) { render :new, status: :unauthorized }
  end

  def sign_in_and_redirect(resource)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end
end
