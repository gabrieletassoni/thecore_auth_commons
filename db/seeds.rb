puts "Loading ThecoreAuthCommons seeds"
email = "admin@#{ENV["BASE_DOMAIN"].presence || "example.com"}"
psswd = ENV["ADMIN_PASSWORD"].presence || "changeme"

unless User.where(admin: true).exists?
    u = User.find_or_initialize_by(email: email)
    u.password = u.password_confirmation = psswd
    u.admin = true
    u.save(validate: false)
end

@values = {
    predicates: %i[can cannot],
    actions: %i[manage create read update destroy],
    targets: ApplicationRecord.subclasses.map {|d| d.to_s.underscore}.to_a.unshift("all")
}

def fill table
    model = table.to_s.classify.constantize
    model.reset_column_information
    puts " - Filling table #{table} with #{@values[table].count} elements:"
    @values[table].each do |name|
        puts "   - Name: #{name}"
        model.find_or_create_by name: name
    end
end

fill :predicates
fill :actions
fill :targets
