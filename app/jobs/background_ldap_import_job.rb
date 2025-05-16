class BackgroundLdapImportJob < ApplicationJob
    queue_as "#{ENV["COMPOSE_PROJECT_NAME"]}_default".to_sym
  
    def perform
        ThecoreAuthCommons.import_ldap_users_task
    end
end