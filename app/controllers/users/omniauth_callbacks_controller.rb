# app/controllers/users/omniauth_callbacks_controller.rb
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    callback 'Google', from_params, 'google'
  end

  def entra_id
    callback 'Microsoft Entra ID', from_params, 'entra_id'
  end

  def callback name, from_params, provider
    Rails.logger.info "#{name} callback received with params: #{from_params.inspect}"

    user = ThecoreAuthCommons.check_user from_params[:email], from_params[:name], from_params[:surname], provider

    if user.present?
      sign_out_all_scopes
      flash[:notice] = t 'devise.omniauth_callbacks.success', kind: name
      sign_in_and_redirect user, event: :authentication
    else
      flash[:alert] = t 'devise.omniauth_callbacks.failure', kind: name, reason: "#{from_params[:email]} is not authorized."
      redirect_to new_user_session_path
    end
  end

  def from_params
    Rails.logger.info "Omniauth params: #{auth.info.inspect}"
    @from_params ||= {
      uid: auth.uid,
      email: auth.info.email,
      # in the params from Microsoft or Google there must be laso the name and surname, maybe with different key, assign them to the name and surname keys in this object
      name: auth.info.given_name.presence || auth.info.first_name.presence || auth.info.name,
      surname: auth.info.family_name.presence || auth.info.last_name.presence || auth.info.surname
    }
  end

  def auth
    @auth ||= request.env['omniauth.auth']
  end
end