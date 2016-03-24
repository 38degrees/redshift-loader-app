class Table < ActiveRecord::Base
    
    belongs_to :job
    has_many :table_copies

    def self.admin_fields 
        {
          :job_id => :lookup,
          :source_name => :text,
          :destination_name => :text,
          :primary_key => :text,
          :updated_key => :text,
          :insert_only => :check_box,
          :max_updated_key => :text,
          :max_primary_key => :text
        }
    end

    def source_connection
        job.source_connection
    end

    def destination_connection
        job.destination_connection
    end

    #rough-n-ready check if the tables have the same columns
    def check
        source_columns = source_connection.columns(source_name).map{|col| col.name }
        destination_columns = destination_connection.columns(destination_name).map{|col| col.name }
        unless source_columns.sort == destination_columns.sort
            raise "Aborting copy! Tables #{source_name}, #{destination_name} don't match."
        end
    end

    def source_columns
        destination_connection.columns(destination_name).map{|col| "#{source_name}.#{col.name}" }
    end

    def where_statement_for_source

        unless max_updated_key
            update_attribute(:max_updated_key, '1970-01-01')
        end

        unless max_primary_key
            update_attribute(:max_primary_key, 0)
        end

        #use this to rewind and catch up some data
        if reset_updated_key
            update_attributes({
                max_updated_key: reset_updated_key,
                max_primary_key: 0,
                reset_updated_key: nil
                })
        end

        if insert_only
            "WHERE #{primary_key} > #{max_primary_key}"
        else
            "WHERE ( #{updated_key} >= '#{max_updated_key.strftime('%Y-%m-%d %H:%M:%S.%N')}' AND #{primary_key} > #{max_primary_key}) OR #{updated_key} > '#{max_updated_key.strftime('%Y-%m-%d %H:%M:%S.%N')}'"
        end
    end

    def new_rows
            sql = "SELECT #{source_columns.join(',')} FROM #{source_name} #{where_statement_for_source} ORDER BY #{updated_key}, #{primary_key} ASC LIMIT #{import_row_limit}" 
            source_connection.execute(sql)
    end


    def check_for_time_travelling_data

        # If data with an older 'updated_at' is inserted into a table after newer data has been loaded it will not be picked up. We can check to see if this has happened (heuristically) by looking at the count of data before the current max_updated_key in both databases. If everything is normal then count of destination.updated_key will be >= count of source.updated_key. Therefore if count destination.updated_key < count source.updated_key we assume that data has time travelled and rewind the max_updated_key

        if time_travel_scan_back_period
            sql = "SELECT COUNT(*) as count FROM #{destination_name} WHERE #{updated_key} >= '#{max_updated_key - time_travel_scan_back_period}' AND #{updated_key} < '#{max_updated_key}'"
            destination_count = destination_connection.execute(sql).first['count'].to_i

            sql = "SELECT COUNT(*) as count FROM #{source_name} WHERE #{updated_key} >= '#{max_updated_key - time_travel_scan_back_period}' AND #{updated_key} < '#{max_updated_key}'"
            source_count = source_connection.execute(sql).first['count'].to_i

            if source_count > destination_count
                update_attribute(:reset_updated_key, max_updated_key - time_travel_scan_back_period)
            end
        end
    end

    def copy
        started_at = Time.now         
        self.check
        self.check_for_time_travelling_data  

        result = self.new_rows
        if result.count > 0
            destination_connection.execute("CREATE TEMP TABLE stage (LIKE #{destination_name});")

            result.each_slice(import_chunk_size) do |slice|
                csv_string = CSV.generate do |csv|
                  slice.each do |row|
                      csv << row.values
                  end
                end

                filename = "#{source_name}_#{Time.now.to_i}.txt"
                text_file = bucket.objects.build(filename)
                text_file.content = csv_string
                text_file.save

                # Import the data to Redshift
                destination_connection.execute("COPY stage from 's3://#{bucket_name}/#{filename}' 
                  credentials 'aws_access_key_id=#{ENV['AWS_ACCESS_KEY_ID']};aws_secret_access_key=#{ENV['AWS_SECRET_ACCESS_KEY']}' delimiter ',' CSV QUOTE AS '\"' ;")

                text_file.destroy
            end

            destination_connection.transaction do
                unless insert_only
                    destination_connection.execute("DELETE FROM #{destination_name} USING stage WHERE #{destination_name}.#{primary_key} = stage.#{primary_key}")
                end
                destination_connection.execute("INSERT INTO #{destination_name} SELECT * FROM stage")
            end

            #update max_updated_at and max_primary_key
            x = destination_connection.execute("SELECT MAX(#{primary_key}) as max_primary_key, MAX(#{updated_key}) as max_updated_key
                FROM stage WHERE #{updated_key} = (SELECT MAX(#{updated_key}) FROM stage)").first

            puts x['max_updated_key']
            update_attributes({
                max_primary_key: x['max_primary_key'].to_i,
                max_updated_key: x['max_updated_key']
                })

            destination_connection.execute("DROP TABLE stage;")
        end

        #Log for benchmarking
        finished_at = Time.now
        self.table_copies << TableCopy.create(text: "Copied #{source_name} to #{destination_name}", rows_copied: result.count, started_at: started_at, finished_at: finished_at)

        # Do it again if we hit up against the row limit
        if result.count == import_row_limit
            copy
        end
    end

    def import_row_limit
        ENV['IMPORT_ROW_LIMIT'] ? ENV['IMPORT_ROW_LIMIT'].to_i : 100000
    end

    def import_chunk_size
        ENV['IMPORT_CHUNK_SIZE'] ? ENV['IMPORT_CHUNK_SIZE'].to_i : 10000
    end

    def s3
        S3::Service.new(:access_key_id => ENV['AWS_ACCESS_KEY_ID'],
                          :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'])
    end

    def bucket_name 
        ENV['S3_BUCKET_NAME']
    end

    def bucket
        s3.buckets.find(bucket_name)
    end

end