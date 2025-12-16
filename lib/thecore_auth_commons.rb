require "devise"
require "cancancan"
require "kaminari"
require "activerecord-nulldb-adapter"
require "thecore_settings"
require "net/ldap"
require "omniauth"
require "omniauth-google-oauth2"
require "omniauth-entra-id"

require "thecore_auth_commons/engine"

require "thecore/seed"

module ThecoreAuthCommons
  def self.oauth_vars?
    entra_id_vars? || google_oauth2_vars?
  end

  def self.entra_id_vars?
    ENV["ENTRA_CLIENT_ID"].present? && ENV["ENTRA_CLIENT_SECRET"].present? && ENV["ENTRA_TENANT_ID"].present?
  end

  def self.google_oauth2_vars?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end

  # Controlla se l'utente esiste, altrimenti lo crea con una password casuale
  # e lo restituisce. Se l'utente esiste già, lo restituisce senza modificarlo.

  def self.check_user(email, name, surname, provider)
    u = User.find_or_initialize_by(email: email)
    u.name = name
    u.surname = surname
    u.password = u.password_confirmation = generate_secure_password
    u.auth_source = provider # 'google' or 'microsoft'
    u.admin = true
    u.save if u.changed?
    u
  end

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
          password: server.admin_password,
        },
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
        ThecoreAuthCommons.align_user email, entry, server
        imported_count += 1
      end
    end

    puts "== Completato. Utenti importati: #{imported_count} =="
  end

  def self.align_user(email, entry, server)
    user = User.find_or_initialize_by(email: email)
    user.auth_source = "ldap #{server.id}"

    # Password don't need to be changed, just created, otherwise it will invalidate the current user session if it's logged in
    user.password = user.password_confirmation = ThecoreAuthCommons.generate_secure_password if user.new_record?

    # Eventuale mapping LDAP -> campi User
    user.name = entry[server.name]&.first if user.respond_to?(:name) && server.name.present?
    user.surname = entry[server.surname]&.first if user.respond_to?(:surname) && server.surname.present?
    user.phone = entry[server.phone]&.first if user.respond_to?(:phone) && server.phone.present?
    user.code = entry[server.code]&.first if user.respond_to?(:code) && server.code.present?

    # Recupera dalla entry i gruppi di cui fa parte l'utente e crea i relativi record in Role assegnandoli all'utente corrente
    is_admin = false
    entry[:memberOf].each do |group|
      group_name = group.split(",").first.split("=").last
      # Se il gruppo è un admin, assegna il ruolo admin
      is_admin = true if ["Administrators", "Domain Admins", "Schema Admins", "Enterprise Admins", "admins", "administrators"].include?(group_name)

      role = Role.find_or_create_by(name: group_name)
      user.roles << role unless user.roles.include?(role)
    end

    user.admin = is_admin if user.respond_to?(:admin)
    # Se l'utente è nuovo o ha cambiato qualcosa, salvalo
    puts "Cannot save user #{email} with errors: #{user.errors.full_messages.join(", ")}" unless user.save(:validate => false) # if user.new_record? || user.changed? || user.roles_changed?
    user
  end

  def self.generate_secure_password(length = 20)
    raise ArgumentError, "Length must be at least 4" if length < 4

    # Caratteri da cui attingere
    lowercase = ("a".."z").to_a
    uppercase = ("A".."Z").to_a
    numbers = ("0".."9").to_a
    symbols = ["!", "@", "#", "$", "%", "&", "*", "?", "-", "_", "+", "="]

    # Obbliga almeno un carattere da ogni gruppo
    password = [
      lowercase.sample,
      uppercase.sample,
      numbers.sample,
      symbols.sample,
    ]

    # Caratteri restanti scelti a caso tra tutti
    all_characters = lowercase + uppercase + numbers + symbols
    (length - 4).times { password << all_characters.sample }

    # Mischia per evitare ordine prevedibile
    password.shuffle.join
  end
end
