module RailsAdmin::LdapServer
  extend ActiveSupport::Concern

  included do
    # rails_admin is not a dependency of this gem (thecore_ui_rails_admin, a layer above, brings
    # it): configure only when RailsAdmin is loaded, so apps/dummies without it can load the model.
    if respond_to?(:rails_admin)
      rails_admin do
        navigation_label I18n.t('admin.settings.label')
        navigation_icon 'fa fa-passport'
      end
    end
  end
end