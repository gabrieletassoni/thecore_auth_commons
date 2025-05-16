# lib/tasks/ldap.rake
namespace :ldap do
  desc "Importa utenti da LDAP e sincronizzali nel database locale"
  task sync_users: :environment do
    ThecoreAuthCommons.import_ldap_users_task
  end
end
