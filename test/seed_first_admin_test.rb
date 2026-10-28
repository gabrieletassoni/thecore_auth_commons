require "test_helper"
require "tmpdir"

# The seed creates the first admin only on a database without any. Its password comes from
# ADMIN_PASSWORD, or is random and written to storage/admin_initial_password (0600), never
# to the log: a fixed fallback gave every installation without ADMIN_PASSWORD a known admin.
class SeedFirstAdminTest < ActiveSupport::TestCase
  setup do
    User.where(admin: true).delete_all
    @storage_dir = Dir.mktmpdir
    @password_file = File.join(@storage_dir, "admin_initial_password")
    @saved_env = ENV.to_h.slice("ADMIN_PASSWORD", "BASE_DOMAIN")
    ENV.delete("ADMIN_PASSWORD")
    ENV["BASE_DOMAIN"] = "seed.example.com"
  end

  teardown do
    FileUtils.remove_entry(@storage_dir)
    %w[ADMIN_PASSWORD BASE_DOMAIN].each { |k| @saved_env.key?(k) ? ENV[k] = @saved_env[k] : ENV.delete(k) }
  end

  def seed
    out, = capture_io { ThecoreAuthCommons.seed_first_admin(storage_dir: @storage_dir) }
    out
  end

  test "without ADMIN_PASSWORD the admin gets a random password, written only to a 0600 file" do
    out = seed

    password = File.read(@password_file).strip
    admin = User.find_by!(email: "admin@seed.example.com", admin: true)
    assert admin.valid_password?(password)
    refute admin.valid_password?("Change#1")
    assert_equal "600", format("%o", File.stat(@password_file).mode & 0o777)
    refute_includes out, password
    assert_includes out, "admin@seed.example.com"
    assert_includes out, @password_file
  end

  test "two installations do not get the same password" do
    seed
    first = File.read(@password_file).strip
    User.where(admin: true).delete_all
    File.delete(@password_file)

    seed

    refute_equal first, File.read(@password_file).strip
  end

  test "with ADMIN_PASSWORD the admin gets it and no file is written" do
    ENV["ADMIN_PASSWORD"] = "Given#Pass1"

    out = seed

    assert User.find_by!(email: "admin@seed.example.com").valid_password?("Given#Pass1")
    refute File.exist?(@password_file)
    refute_includes out, "Given#Pass1"
  end

  test "an existing admin is left alone and no file is written" do
    admin = User.create!(email: "existing@example.com", admin: true,
                         password: "Existing#1", password_confirmation: "Existing#1")

    seed

    assert admin.reload.valid_password?("Existing#1")
    assert_equal [admin], User.where(admin: true).to_a
    refute File.exist?(@password_file)
  end

  test "a failed save leaves no password file behind, so the next seed can retry" do
    failing = User.new
    failing.define_singleton_method(:save!) { |**| raise ActiveRecord::RecordNotSaved, "boom" }
    User.define_singleton_method(:find_or_initialize_by) { |**| failing }

    assert_raises(ActiveRecord::RecordNotSaved) { seed }
    refute File.exist?(@password_file)
  ensure
    User.singleton_class.remove_method(:find_or_initialize_by)
  end

  test "an existing password file is never overwritten" do
    File.write(@password_file, "kept\n")

    seed

    assert_equal "kept\n", File.read(@password_file)
    refute User.where(admin: true).exists?
  end
end
