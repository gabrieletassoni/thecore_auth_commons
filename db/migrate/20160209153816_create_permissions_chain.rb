class CreatePermissionsChain < ActiveRecord::Migration[7.0]
  def change
    # Predicates
    create_table :predicates, if_not_exists: true do |t|
      t.string :name
      t.bigint :lock_version

      t.timestamps
    end
    add_index :predicates, :name, unique: true, if_not_exists: true
    
    # Actions
    create_table :actions, if_not_exists: true do |t|
      t.string :name
      t.bigint :lock_version

      t.timestamps
    end
    add_index :actions, :name, unique: true, if_not_exists: true
    
    # Targets
    create_table :targets, if_not_exists: true do |t|
      t.string :name
      t.bigint :lock_version

      t.timestamps
    end
    add_index :targets, :name, unique: true, if_not_exists: true

    create_table :permissions, if_not_exists: true do |t|
      t.references :predicate, null: false, foreign_key: true
      t.references :action, null: false, foreign_key: true
      t.references :target, null: false, foreign_key: true
      t.bigint :lock_version

      t.timestamps
    end
    # Association table
    create_table :permission_roles, if_not_exists: true do |t|
      t.references :role, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.bigint :lock_version

      t.timestamps
    end
  end
end
