namespace :db do
  desc "Load migrations sources from migration files for finded version"
  task :load_migrations_sources => :environment do
    puts "======== Start loading migrations sources to database."

    migrations = ActiveRecord::Migrator.migrations(ActiveRecord::Migrator.migrations_paths)
    migrations.each do |migration|

      schema_migration = ActiveRecord::SchemaMigration.find_by(version: migration.version)

      if schema_migration.present?
        puts "- loaded #{migration.name} (#{migration.version})"
        schema_migration.update_attributes(source: File.binread(migration.filename))
      else
        puts "- skiped #{migration.name} (#{migration.version})"
      end

    end

    puts "======== Migrations sources loaded."
  end

  desc "Auto rollback migrations to the last version of migration files"
  task :auto_rollback => :environment do
    ActiveRecord::Migrator.auto_rollback
  end

end
