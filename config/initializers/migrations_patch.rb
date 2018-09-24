module ActiveRecordMigratorPatch

  module ClassMethods
    def auto_rollback
      # Code based on Migrator#down method
      migrations = pending_rollback_db_migrations
      migrations.select! { |m| yield m } if block_given?
      new(:down, migrations).migrate
    end

    def pending_rollback_db_migrations
      # Last version from migrations source files
      source_last_version = ActiveRecord::Migrator.last_migration.version
      # Completed migrations that need to be rolled back
      ActiveRecord::SchemaMigration.where("version > '?'", source_last_version).map do |migrartion|
        DbSourceMigrationProxy.new(migrartion.version, migrartion.source)
      end
    end
  end

  def self.prepended(base)
    class << base
      prepend ClassMethods
    end

  end

  private

  # Overrided method!
  def execute_migration_in_transaction(migration, direction)
    return if down? && !migrated.include?(migration.version.to_i)
    return if up?   &&  migrated.include?(migration.version.to_i)

    ActiveRecord::Base.logger.info "Migrating to #{migration.name} (#{migration.version})" if ActiveRecord::Base.logger

    ddl_transaction(migration) do
      migration.migrate(direction)
      record_version_state_after_migrating(migration.version)
      # New behavior.
      # record_source_after_migrating(migration.filename) if up?
    end
  rescue => e
    msg = "An error has occurred, "
    msg << "this and " if use_transaction?(migration)
    msg << "all later migrations canceled:\n\n#{e}"
    raise StandardError, msg, e.backtrace
  end

  def record_source_after_migrating(source_file_name)
    ActiveRecord::SchemaMigration.last.update_attributes(source: File.binread(source_file_name))
  end

  class DbSourceMigrationProxy < ActiveRecord::MigrationProxy

    attr_reader :source
    def initialize(version, source)
      super(nil, version, nil, nil)
      @source = source
    end

    private

      # Overrided method!
      def load_migration
        eval(self.source, TOPLEVEL_BINDING)

        class_name_regex = /^class\s(\w+)\s</
        name = source.match(class_name_regex).captures[0]

        name.constantize.new(name, version)
      end

  end

end


ActiveRecord::Migrator.prepend(ActiveRecordMigratorPatch)
