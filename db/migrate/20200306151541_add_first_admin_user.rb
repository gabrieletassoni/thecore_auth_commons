class AddFirstAdminUser < ActiveRecord::Migration[6.0]
  email = "admin@example.com"

  def up
    User.reset_column_information
    u=User.find_or_initialize_by(email: email)
    u.username = "admin"
    psswd = SecureRandom.hex(5)
    puts "\nPassword for user #{email} is:\n\n\t\t#{psswd}\n\n\tplease save it somewhere, securely."
    File.open('.passwords', 'w') do |f|
      f.write(psswd)
    end
    # Rails.application.credentials[Rails.env.to_sym][:admin_password] = psswd
    u.password = psswd
    u.password_confirmation = psswd
    u.admin = true
    u.save!
  end

  def down
    User.find_by(email: email).destroy
  end
end
