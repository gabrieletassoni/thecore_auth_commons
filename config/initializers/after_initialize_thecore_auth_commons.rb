require 'thecore_auth_commons_actioncontroller_concerns'

# App Config
Rails.application.configure do
    config.after_initialize do
        # In development be sure to load all the namespaces
        # in order to have working reflection and meta-programming.
        Zeitwerk::Loader.eager_load_all if Rails.env.development?
    end
end