class Job < ActiveRecord::Base
    has_many :tables

    def self.admin_fields 
        {
          :name => :text,
          :tables => :collection,
          :source_connection_string => :text,
          :destination_connection_string => :text
        }
    end

    def run
        setup_connection
        tables.each do |table|
            puts "Copying #{table.source_name} to #{table.destination_name}"
            logger.info "Copying #{table.source_name} to #{table.destination_name}"
            table.copy
        end
    end

    def reset(confirmation)
      return "Confirmation failed" unless confirmation == self.name
      setup_connection
      self.tables.each do |table|
        puts "Resetting #{table.destination_name}"
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
      if column_types.has_key? column_type
        column_types[column_type]
      else
        column_type
      end
    end

    def setup_connection
        SourceDb.establish_connection source_connection_string
        DestinationDb.establish_connection destination_connection_string
    end

    def source_connection
      SourceDb.connection
    end

    def destination_connection
      DestinationDb.connection
    end

    # Discovers all tables in source
    def setup
      setup_connection

      unless tables.count == 0
        puts "Aborting! Job already has tables attached. Setup requires a new job."
        return
      end
      source_tables = source_connection.tables
      source_tables = source_tables.reject { |table| 
        exclude_table_names.include?(table) || table.starts_with?('tmp_') 
      }

      source_tables.each do |table|
        puts "Creating #{table}"
        destination_connection.create_table table, id: false do |t|
          source_connection.columns(table).each do |column|
            #create table
            t.column column.name, convert_column_type(column.sql_type)
          end
        end

        #create entry in tables table
        pk = source_connection.columns(table).select{|c| c.primary}
        primary_key = if pk.count == 1
          pk.first.name
        else
          ""
        end
        uk = source_connection.columns(table).select{|c| c.name == "updated_at"}
        updated_key = if uk.count == 1
          uk.first.name
        else
          ""
        end

        self.tables << Table.new({source_name: table, destination_name: table, primary_key: primary_key, updated_key: updated_key, insert_only: false})
      end

      puts "Done setup!"
      puts "Warning! Table settings have been guessed but you can do extra configuration such as setting the insert_only flag on tables to further increase speed of loading."

    end

end