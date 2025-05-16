require 'devise'
require 'cancancan'
require 'kaminari'
require 'activerecord-nulldb-adapter'
require "thecore_settings"
require "net/ldap"

require "thecore_auth_commons/engine"

require "thecore/seed"

module ThecoreAuthCommons

  def self.import_ldap_users_task
    puts "== Avvio sincronizzazione utenti da LDAP =="

    imported_count = 0

    LdapServer.all.each do |server|
      puts "Contatto server LDAP: #{server.host} (priorità: #{server.priority})"

      ldap = Net::LDAP.new(
        host: server.host,
        port: server.port,
        encryption: server.use_ssl ? :simple_tls : nil,
        auth: {
          method: :simple,
          username: server.admin_user,
          password: server.admin_password
        }
      )

      unless ldap.bind
        puts "❌ Connessione fallita a #{server.host}"
        next
      end

      filter = Net::LDAP::Filter.present(server.auth_field)
      treebase = server.base_dn

      ldap.search(base: treebase, filter: filter) do |entry|
        email = entry[server.auth_field]&.first
        next unless email

        puts "Importando utente: #{email}"

        # Password must contain at least one uppercase letter, one lowercase letter, one number and one special character
        ThecoreAuthCommons.align_user email, entry, server.id
        imported_count += 1
      end
    end

    puts "== Completato. Utenti importati: #{imported_count} =="
  end
  # Your code goes here...
  def self.align_user email, entry, server_id
    user = User.find_or_initialize_by(email: email)
    user.auth_source = "ldap #{server_id}"

    # Password don't need to be changed, just created, otherwise it will invalidate the current user session if it's logged in
    user.password = user.password_confirmation = Devise.friendly_token[0, 20] if user.new_record?

    # Eventuale mapping LDAP -> campi User
    user.name = entry[:givenname]&.first if user.respond_to?(:name)

    # Recupera dala entry i gruppi di cui fa parte l'utente e crea i relativi record in Role assegnandoli all'utente corrente
    is_admin = false
    entry[:memberOf].each do |group|
      group_name = group.split(",").first.split("=").last
      # Se il gruppo è un admin, assegna il ruolo admin
      is_admin = true if [ "Administrators" "Domain Admins", "Schema Admins", "Enterprise Admins", "admins", "administrators" ].include?(group_name)
      
      role = Role.find_or_create_by(name: group_name)
      user.roles << role unless user.roles.include?(role)
    end

    user.admin = is_admin if user.respond_to?(:admin)
    # Se l'utente è nuovo o ha cambiato qualcosa, salvalo
    puts "Cannot save user #{email} with errors: #{user.errors.full_messages.join(", ")}" unless user.save # if user.new_record? || user.changed? || user.roles_changed?
    user
  end
end
