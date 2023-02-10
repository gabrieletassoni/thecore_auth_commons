# Extensions to help during seeding of ThecoreSettings
module Thecore
  class Seed
    def self.save_setting ns, setting, value
      puts "Saving setting if nil #{ns}: #{setting} = #{value}"
      if ::Settings.ns(ns)[setting].blank?
        ::Settings.ns(ns)[setting] if value.blank?
        ::Settings.ns(ns)[setting] = value unless value.blank?
      end
    end

    def self.delete_setting ns, setting
      puts "Removing setting #{ns}: #{setting}"
      ThecoreSettings::Setting.where(ns: ns, key: setting).destroy_all
    end
  end
end
  