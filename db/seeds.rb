puts "Loading ThecoreAuthCommons seeds"

# Needing this since in the rake task is not aeger loaded
Zeitwerk::Loader.eager_load_all

ThecoreAuthCommons.seed_first_admin

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
