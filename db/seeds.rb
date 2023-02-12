puts "Loading ThecoreAuthCommons seeds"
email = "admin@#{ENV["BASE_DOMAIN"]}"
psswd = ENV["ADMIN_PASSWORD"].presence || "changeme"

unless User.where(admin: true).exists?
    u = User.find_or_initialize_by(email: email)
    u.username = "Administrator" if u.respond_to? :username=
    u.password = u.password_confirmation = psswd
    u.admin = true
    u.save(validate: false)
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
