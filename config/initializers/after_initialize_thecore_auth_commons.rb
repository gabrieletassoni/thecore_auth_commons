require 'thecore_auth_commons_actioncontroller_concerns'

Rails.application.configure do
    config.after_initialize do
        # In development be sure to load all the namespaces
        # in order to have working reflection and meta-programming.
        # 
        if Rails.env.development?
            Rails.configuration.eager_load_namespaces.each(&:eager_load!) if Rails.version.to_i == 5 #Rails 5
            Zeitwerk::Loader.eager_load_all if Rails.version.to_i >= 6 #Rails 6
        end

        ActionController.send(:include, ::ThecoreAuthCommonsActioncontrollerConcerns)
    end
end