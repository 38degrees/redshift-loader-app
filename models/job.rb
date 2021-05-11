class Job < ActiveRecord::Base
  has_many :tables

  def self.admin_fields
    {
      id: { type: :number, edit: false },
      name: :text,
      tables: :collection,
      source_connection_string: :text,
      destination_connection_string: :text
    }
  end

  def run
    started_at = Time.now
    logger.info "Running job #{name}"

    setup_connection
    tables.each do |table|
      puts "Job #{name} - Copying #{table.source_name} to #{table.destination_name}"
      logger.info "Job #{name} - Copying #{table.source_name} to #{table.destination_name}"
      table.copy
    end

    finished_at = Time.now
    logger.info "Total time taken to run job #{name} was #{finished_at - started_at} seconds"
  end

  def reset(confirmation)
    return "Confirmation failed" unless confirmation == name

    setup_connection
    tables.each do |table|
      puts "Resetting #{table.destination_name}"
      logger.info "Resetting #{table.destination_name}"
      table.update_attributes({
                                delete_on_reset: true,
                                reset_updated_key: '1970-01-01 00:00:00'
                              })
    end
  end

  def exclude_table_names
    ["schema_migrations"]
  end

  def column_types
    {
      "json" => "varchar(65535)",
      "text" => "varchar(65535)"
    }
  end

  def convert_column_type(column_type)
    if column_types.key? column_type
      column_types[column_type]
    else
      column_type
    end
  end

  def setup_connection
    SourceDb.setup_connection(id, source_connection_string)
    DestinationDb.setup_connection(id, destination_connection_string)
  end

  def source_connection
    SourceDb.get_connection(id)
  end

  def destination_connection
    DestinationDb.get_connection(id)
  end

  # Discovers all tables in source
  def setup
    setup_connection

    unless tables.count.zero?
      puts "Aborting! Job already has tables attached. Setup requires a new job."
      return
    end
    source_tables = source_connection.tables
    source_tables = source_tables.reject do |table|
      exclude_table_names.include?(table) || table.starts_with?('tmp_')
    end

    source_tables.each do |table|
      puts "Creating #{table}"
      destination_connection.create_table table, id: false do |t|
        source_connection.columns(table).each do |column|
          # create table
          t.column column.name, convert_column_type(column.sql_type)
        end
      end

      # create entry in tables table
      pk = source_connection.columns(table).select(&:primary)
      primary_key = if pk.count == 1
                      pk.first.name
                    else
                      ""
                    end
      uk = source_connection.columns(table).select { |c| c.name == "updated_at" }
      updated_key = if uk.count == 1
                      uk.first.name
                    else
                      ""
                    end

      tables << Table.new({ source_name: table, destination_name: table, primary_key: primary_key, updated_key: updated_key, insert_only: false })
    end

    puts "Done setup!"
    puts "Warning! Table settings have been guessed but you can do extra configuration such as setting the insert_only flag on tables to further increase speed of loading."
  end
end
