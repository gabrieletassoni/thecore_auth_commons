Rails.application.configure do
    config.after_initialize do
        # In development be sure to load all the namespaces
        # in order to have working reflection and meta-programming.
        Zeitwerk::Loader.eager_load_all if Rails.env.development?
        
        Ability.send(:include, ThecoreAuthCommonsCanCanCanConcern)
        User.send(:include, ThecoreAuthCommonsUserConcern)
        # User.devise_modules.delete(:recoverable) if ThecoreSettings::Setting.where(ns: :devise, key: :recoverable).first.present? && ThecoreSettings::Setting.where(ns: :devise, key: :recoverable).first.raw == "disable"
        # User.devise_modules.delete(:registerable) if ThecoreSettings::Setting.where(ns: :devise, key: :registerable).first.present? && ThecoreSettings::Setting.where(ns: :devise, key: :registerable).first.raw == "disable"
    end
end