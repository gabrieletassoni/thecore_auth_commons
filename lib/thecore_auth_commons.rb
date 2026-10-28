require "devise"
require "cancancan"
require "kaminari"
# activerecord-nulldb-adapter reaches into ActiveRecord::ConnectionAdapters internals
# (e.g. SqlTypeMetadata::Deduplicable) that aren't necessarily loaded yet under a bare,
# non-Rails-booted `require` chain (e.g. model_driven_api's plain minitest path) — make sure
# ActiveRecord itself is fully loaded first.
require "active_record"
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

  # Restituisce l'utente con l'email verificata dal provider OAuth, creandolo se non esiste:
  # password casuale, auth_source = provider, nessun admin e nessun ruolo (si assegnano a mano).
  # Di un utente esistente aggiorna solo nome e cognome: password, admin e auth_source restano,
  # così chi ha anche una password locale può continuare a usarla. nil se l'utente non è salvabile.
  def self.check_user(email, name, surname, provider)
    return if email.blank?

    u = User.find_or_initialize_by(email: email.to_s.strip.downcase)
    u.name = name if u.respond_to?(:name=)
    u.surname = surname if u.respond_to?(:surname=)
    if u.new_record?
      u.password = u.password_confirmation = generate_secure_password
      u.auth_source = provider # 'google' or 'microsoft'
    end
    u.save if u.changed?
    u if u.persisted?
  end

  INITIAL_ADMIN_PASSWORD_FILE = "admin_initial_password".freeze

  # Crea il primo admin, solo se nel DB non ce n'è nessuno. La password è ADMIN_PASSWORD,
  # oppure una casuale scritta in <storage_dir>/admin_initial_password (0600) e mai nel log.
  # Un file già presente non viene mai sovrascritto: in quel caso l'admin non viene creato.
  # Se il salvataggio fallisce il file viene tolto, così il seed successivo può riprovare.
  def self.seed_first_admin(storage_dir: Rails.root.join("storage"))
    return if User.where(admin: true).exists?

    email = "admin@#{ENV["BASE_DOMAIN"].presence || "example.com"}"
    password = ENV["ADMIN_PASSWORD"].presence
    unless password
      generated_password_file = File.join(storage_dir.to_s, INITIAL_ADMIN_PASSWORD_FILE)
      password = generate_secure_password
      begin
        FileUtils.mkdir_p(storage_dir.to_s)
        # EXCL: mai sovrascrivere, anche con backend e worker che lanciano il seed insieme
        File.open(generated_password_file, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.puts password }
      rescue Errno::EEXIST
        puts "Admin #{email} NON creato: #{generated_password_file} esiste già. Cancellalo e rilancia il seed."
        return
      end
    end

    begin
      u = User.find_or_initialize_by(email: email)
      u.password = u.password_confirmation = password
      u.admin = true
      u.save!(validate: false)
    rescue StandardError
      File.delete(generated_password_file) if generated_password_file
      raise
    end
    puts(generated_password_file ? "Admin #{email} creato: password in #{generated_password_file}" : "Admin #{email} creato con la password di ADMIN_PASSWORD")
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

    user.admin = is_admin if user.respond_to?(:admin) && !user.admin # Se l'utente è già admin non revocargli l'admin, altrimenti se è nuovo o non era admin assegnagli l'admin se è presente nei gruppi admin
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
      lowercase.sample(random: SecureRandom),
      uppercase.sample(random: SecureRandom),
      numbers.sample(random: SecureRandom),
      symbols.sample(random: SecureRandom),
    ]

    # Caratteri restanti scelti a caso tra tutti
    all_characters = lowercase + uppercase + numbers + symbols
    (length - 4).times { password << all_characters.sample(random: SecureRandom) }

    # Mischia per evitare ordine prevedibile
    password.shuffle(random: SecureRandom).join
  end
end
