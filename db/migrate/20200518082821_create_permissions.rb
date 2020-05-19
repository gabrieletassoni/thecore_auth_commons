class CreatePermissions < ActiveRecord::Migration[6.0]
  def change
    @values = {
      predicates: %i[can cannot],
      actions: %i[manage create read update destroy],
      targets: ApplicationRecord.subclasses.map {|d| d.to_s.underscore}.to_a.unshift(:all)
    }

    def create_and_fill table
      create_table table do |t|
        t.string :name
        t.bigint :lock_version

        t.timestamps
      end
      add_index table, :name, unique: true
      model = table.to_s.classify.constantize
      model.reset_column_information
      model.upsert_all @values[table].map { |p| {name: p, created_at: Time.now, updated_at: Time.now} }, unique_by: [:name]
    end

    # Predicates
    create_and_fill :predicates
    
    # Actions
    create_and_fill :actions
    
    # Targets
    create_and_fill :targets

    create_table :permissions do |t|
      t.references :predicate, null: false, foreign_key: true
      t.references :action, null: false, foreign_key: true
      t.references :target, null: false, foreign_key: true
      t.bigint :lock_version

      t.timestamps
    end
    # Association table
    create_table :permission_roles do |t|
      t.references :role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.bigint :lock_version

      t.timestamps
    end
  end
end
