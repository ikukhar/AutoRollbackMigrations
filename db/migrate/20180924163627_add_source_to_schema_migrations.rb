class AddSourceToSchemaMigrations < ActiveRecord::Migration[5.0]
  def change
    add_column :schema_migrations, :source, :text
  end
end
