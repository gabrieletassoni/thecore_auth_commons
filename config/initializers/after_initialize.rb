Rails.application.configure do
    config.after_initialize do
        # In development be sure to load all the namespaces
        # in order to have working reflection
        Zeitwerk::Loader.eager_load_all if Rails.env.development?

        # Devise.timeout_in = ENV.fetch('SESSION_TIMEOUT_IN_MINUTES', 31).to_i.minutes
        # Devise.password_length = ENV.fetch('MIN_PASSWORD_LENGTH', 8).to_i..128
        
        Ability.send(:include, ThecoreAuthCommonsCanCanCanConcern)
        User.send(:include, ThecoreAuthCommonsUserConcern)
    end
end