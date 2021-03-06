module ThecoreAuthCommons
  class Engine < ::Rails::Engine
    # https://stackoverflow.com/questions/12161376/rails-3-2-adding-seed-tasks-from-a-mountable-engine

    initializer 'thecore_auth_commons.add_to_migrations' do |app|
      # Adds the list of Thecore Engines, so to manage seeds loading, i.e.:
      # Thecore::Base.thecore_engines.each { |engine| engine.load_seed }
      Thecore::Base.thecore_engines << self.class
      unless app.root.to_s.match root.to_s
        # APPEND TO MAIN APP MIGRATIONS FROM THIS GEM
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end
  end
end
