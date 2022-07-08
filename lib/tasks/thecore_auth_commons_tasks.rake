# desc "Explaining what the task does"
# task :thecore_auth_commons do
#   # Task goes here
# end
namespace :thecore do
    namespace :db do
        desc "Load seeds from thecore engines seed files, it also runs rails db:seed as last action."
        task seed: :environment do
            Thecore::Base.thecore_engines.each { |engine| engine.send :load_seed }
            Rake::Task["db:seed"].reenable
            Rake::Task["db:seed"].invoke
        end
        desc "Creates DB if not exists, then init it with all Thecore compatible seeds."
        task init: :environment do
            Rake::Task["db:create"].reenable
            Rake::Task["db:create"].invoke
            Rake::Task["db:migrate"].reenable
            Rake::Task["db:migrate"].invoke
            Rake::Task["thecore:db:seed"].reenable
            Rake::Task["thecore:db:seed"].invoke
        end
        desc "Keeps the DB updated by applying latest migrations and data seeding."
        task update: :environment do
            Rake::Task["thecore:db:init"].reenable
            Rake::Task["thecore:db:init"].invoke
        end
    end
end
