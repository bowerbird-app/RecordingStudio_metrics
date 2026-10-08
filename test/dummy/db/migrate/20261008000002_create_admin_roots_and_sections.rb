# frozen_string_literal: true

class CreateAdminRootsAndSections < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_roots, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false

      t.timestamps
    end

    create_table :admin_sections, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :admin_sections, :key, unique: true
  end
end
