puts "Loading ThecoreAuthCommons seeds"
email = ENV["ADMIN_EMAIL"].presence || "admin@example.com"
psswd = ENV["ADMIN_PASSWORD"].presence || "changeme"

unless User.where(admin: true).exists?
    u = User.find_or_initialize_by(email: email)
    u.username = "Administrator"
    u.password = u.password_confirmation = psswd
    u.admin = true
    u.save(validate: false)
end

# If there are previous users without the access_token, create it:
User.all.each do |u|
    if u.access_token.blank?
        begin
            u.access_token = SecureRandom.uuid #urlsafe_base64(32)
        end while ::User.exists?(access_token: self.access_token)
        u.save(validate: false)
    end
end

@values = {
    predicates: %i[can cannot],
    actions: %i[manage create read update destroy],
    targets: ApplicationRecord.subclasses.map {|d| d.to_s.underscore}.to_a.unshift(:all)
}

def fill table
    model = table.to_s.classify.constantize
    model.reset_column_information
    model.upsert_all @values[table].map { |p| {name: p, created_at: Time.now, updated_at: Time.now} }, unique_by: [:name]
end

fill :predicates
fill :actions
fill :targets