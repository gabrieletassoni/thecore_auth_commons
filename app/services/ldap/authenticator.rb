# app/services/ldap/authenticator.rb
module Ldap
  class Authenticator
    def initialize(email:, password:)
      @password = password
      @email = email
    end

    def auth_on_single_server(server)
      Rails.logger.debug("LDAP: Trying to authenticate #{email} on server #{server.inspect}")
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

      Rails.logger.debug("LDAP: Binding to server #{server.inspect} ")
      filter = Net::LDAP::Filter.eq(server.auth_field, email) # server.auth_field
      treebase = server.base_dn

      Rails.logger.debug("LDAP: Searching for user #{email} in base #{treebase} with filter #{filter.to_s}")
      ldap.search(base: treebase, filter: filter) do |entry|
        user_dn = entry.dn

        # Prova autenticazione utente
        user_ldap = Net::LDAP.new(
          host: server.host,
          port: server.port,
          encryption: server.use_ssl ? :simple_tls : nil,
          auth: {
            method: :simple,
            username: user_dn,
            password: password,
          },
        )

        Rails.logger.debug("LDAP: Trying to bind as user #{user_dn} on server #{server.inspect}")
        return entry if user_ldap.bind
      end
      Rails.logger.debug("LDAP: Authentication failed for #{email} on server #{server.inspect}")
      nil
    end

    def authenticate
      return nil if @password.blank?

      LdapServer.all.each do |server|
        entry = auth_on_single_server(server)
        if entry
          Rails.logger.info("Authentication: LDAP authentication succeeded for #{email} on server #{server.name}")
          return find_or_create_user(entry, server.id)
        else
          Rails.logger.info("Authentication: LDAP authentication failed for #{email} on server #{server.name}")
        end
      end

      nil
    end

    private

    attr_reader :email, :password

    def find_or_create_user(entry, server_id)
      ThecoreAuthCommons.align_user email, entry, server_id
    end
  end
end
