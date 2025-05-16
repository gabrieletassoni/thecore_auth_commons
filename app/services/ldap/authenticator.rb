# app/services/ldap/authenticator.rb
module Ldap
  class Authenticator
    def initialize(email:, password:)
      @password = password
      @email = email
    end

    def authenticate
      return nil if @password.blank?

      LdapServer.all.each do |server|
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

        filter = Net::LDAP::Filter.eq(server.auth_field, email) # server.auth_field
        treebase = server.base_dn

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
              password: password
            }
          )

          if user_ldap.bind
            return find_or_create_user(entry, server.id)
          end
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
