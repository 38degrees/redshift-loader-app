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
        SourceDb.establish_connection self.source_connection_string
        DestinationDb.establish_connection self.destination_connection_string

        tables.each do |table|
            table.copy
        end
    end

end