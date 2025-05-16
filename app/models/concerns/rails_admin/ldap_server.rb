module RailsAdmin::LdapServer
  extend ActiveSupport::Concern

  included do
    rails_admin do
      navigation_label I18n.t('admin.settings.label')
      navigation_icon 'fa fa-passport'
    end
  end
end