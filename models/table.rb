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

    def copy
        if insert_only
            result = DestinationDb.connection.execute("SELECT MAX(#{primary_key}) AS max FROM #{destination_name}")
            max_primary_key = result.first['max'] || 0
            p "Max #{primary_key} is #{max_primary_key}"

            result = SourceDb.connection.execute("SELECT * FROM #{source_name} WHERE #{primary_key} > #{max_primary_key} ORDER BY #{primary_key} ASC LIMIT #{import_row_limit}")

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
                
                DestinationDb.connection.execute("copy #{destination_name} from 's3://#{bucket_name}/#{filename}' 
                    credentials 'aws_access_key_id=#{ENV['AWS_ACCESS_KEY_ID']};aws_secret_access_key=#{ENV['AWS_SECRET_ACCESS_KEY']}' delimiter ',' CSV QUOTE AS '\"' ;")

                text_file.destroy
            end

        else
            result = DestinationDb.connection.execute("SELECT MAX(#{updated_key}) AS max FROM #{destination_name}")
            max_updated_key = result.first['max'] || 0
            p "Max #{updated_key} is #{max_updated_key}"

            result = SourceDb.connection.execute("SELECT * FROM #{source_name} WHERE #{updated_key} >= '#{max_updated_key}' ORDER BY #{updated_key} ASC LIMIT #{import_row_limit}")

            if result.count > 1
                DestinationDb.connection.execute("CREATE TEMP TABLE stage (LIKE #{destination_name});")

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
                    DestinationDb.connection.execute("COPY stage from 's3://#{bucket_name}/#{filename}' 
                      credentials 'aws_access_key_id=#{ENV['AWS_ACCESS_KEY_ID']};aws_secret_access_key=#{ENV['AWS_SECRET_ACCESS_KEY']}' delimiter ',' CSV QUOTE AS '\"' ;")

                    text_file.destroy
                end

                DestinationDb.transaction do
                    DestinationDb.connection.execute("DELETE FROM #{destination_name} USING stage WHERE #{destination_name}.#{primary_key} = stage.#{primary_key}")
                    DestinationDb.connection.execute("INSERT INTO #{destination_name} SELECT * FROM stage")
                end

                DestinationDb.connection.execute("DROP TABLE stage;")

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