class Table < ActiveRecord::Base
    
    belongs_to :job

    def self.admin_fields 
        {
          :job_id => :lookup,
          :source_name => :text,
          :destination_name => :text,
          :primary_key => :text,
          :updated_key => :text,
          :insert_only => :check_box
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
        source_columns.sort == destination_columns.sort
    end

    def copy
        unless check
            raise "Aborting copy! Tables #{source_name}, #{destination_name} don't match."
        end

        destination_columns = destination_connection.columns(destination_name).map{|col| "#{source_name}.#{col.name}" }

        if insert_only
            result = destination_connection.execute("SELECT MAX(#{primary_key}) AS max FROM #{destination_name}")

            # assumes primary_key is a number
            where_statement = if result.first['max']
                "WHERE #{primary_key} > #{result.first['max']}"
            end

            sql = "SELECT #{destination_columns.join(',')} FROM #{source_name} #{where_statement} ORDER BY #{primary_key} ASC LIMIT #{import_row_limit}"
            logger.info sql

            result = source_connection.execute(sql)

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
                
                destination_connection.execute("copy #{destination_name} from 's3://#{bucket_name}/#{filename}' 
                    credentials 'aws_access_key_id=#{ENV['AWS_ACCESS_KEY_ID']};aws_secret_access_key=#{ENV['AWS_SECRET_ACCESS_KEY']}' delimiter ',' CSV QUOTE AS '\"' ;")

                text_file.destroy
            end

        else
            result = destination_connection.execute("SELECT MAX(#{updated_key}) AS max FROM #{destination_name}")

            max_updated_key = result.first['max']

            where_statement = if max_updated_key 
                result = destination_connection.execute("SELECT MAX(#{primary_key}) AS max FROM #{destination_name} WHERE #{updated_key} = '#{max_updated_key}'")
                max_primary_key = result.first['max']
                "WHERE ( #{updated_key} >= '#{max_updated_key}' AND #{primary_key} > #{max_primary_key}) OR #{updated_key} > '#{max_updated_key}'"
            end

            


            sql = "SELECT #{destination_columns.join(',')} FROM #{source_name} #{where_statement} ORDER BY #{updated_key}, #{primary_key} ASC LIMIT #{import_row_limit}"
            logger.info sql

            result = source_connection.execute(sql)

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
                    destination_connection.execute("DELETE FROM #{destination_name} USING stage WHERE #{destination_name}.#{primary_key} = stage.#{primary_key}")
                    destination_connection.execute("INSERT INTO #{destination_name} SELECT * FROM stage")
                end

                destination_connection.execute("DROP TABLE stage;")

            end
        end
    end

    def import_row_limit
        ENV['IMPORT_ROW_LIMIT'].to_i
    end

    def import_chunk_size
        ENV['IMPORT_CHUNK_SIZE'].to_i
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