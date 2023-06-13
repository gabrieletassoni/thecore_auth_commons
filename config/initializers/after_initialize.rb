Rails.application.configure do
    config.after_initialize do
        # In development be sure to load all the namespaces
        # in order to have working reflection
        Zeitwerk::Loader.eager_load_all if Rails.env.development?
        
        Ability.send(:include, ThecoreAuthCommonsCanCanCanConcern)
        User.send(:include, ThecoreAuthCommonsUserConcern)
    end
end