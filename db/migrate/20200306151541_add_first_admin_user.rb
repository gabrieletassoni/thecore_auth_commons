class AddFirstAdminUser < ActiveRecord::Migration[6.0]
  def up
    email = "admin@example.com"
    User.reset_column_information
    u=User.find_or_initialize_by(email: email)
    psswd = SecureRandom.hex(5)
    u.password = psswd
    u.password_confirmation = psswd
    u.admin = true
    u.save!
    puts "\nPlease find generated initial admin password in .passwords file."
    File.open('.passwords', 'w') do |f|
      f.write(psswd)
    end
  end

  def down
    email = "admin@example.com"
    User.find_by(email: email).destroy
  end
end
