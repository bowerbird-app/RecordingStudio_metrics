# frozen_string_literal: true

class CreateMetricsDemoTables < ActiveRecord::Migration[8.1]
  def change
    create_table :members, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :workspace_id, null: false
      t.string :status, null: false, default: "active"
      t.string :country
      t.boolean :verified, null: false, default: false
      t.integer :age
      t.timestamps
    end
    add_index :members, :workspace_id
    add_index :members, :created_at
    add_index :members, %i[workspace_id status]

    create_table :projects, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :workspace_id, null: false
      t.string :title
      t.bigint :storage_bytes, default: 0, null: false
      t.boolean :completed, null: false, default: false
      t.timestamps
    end
    add_index :projects, :workspace_id
    add_index :projects, :created_at

    create_table :project_images, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :project_id, null: false
      t.integer :file_size, default: 0, null: false
      t.timestamps
    end
    add_index :project_images, :project_id
  end
end
