class CreatePermissions < ActiveRecord::Migration[6.0]
  def change
    # Predicates
    create_table :predicates do |t|
      t.string :name
      t.bigint :lock_version

      t.timestamps
    end
    add_index :predicates, :name, unique: true
    
    # Actions
    create_table :actions do |t|
      t.string :name
      t.bigint :lock_version

      t.timestamps
    end
    add_index :actions, :name, unique: true
    
    # Targets
    create_table :targets do |t|
      t.string :name
      t.bigint :lock_version

      t.timestamps
    end
    add_index :targets, :name, unique: true

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
