# desc "Explaining what the task does"
# task :thecore_auth_commons do
#   # Task goes here
# end
namespace :thecore do
    namespace :db do
        desc "Load seeds from thecore engines seed files, it also runs rails db:seed as last action"
        task seed: :environment do
            Thecore::Base.thecore_engines.each { |engine| engine.send :load_seed }
            Rake::Task["db:seed"].reenable
            Rake::Task["db:seed"].invoke
        end
    end
end
