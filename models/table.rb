class Table < ActiveRecord::Base
    MIN_UPDATED_KEY = '1970-01-01'
    MIN_PRIMARY_KEY = 0
    
    belongs_to :job
    has_many :table_copies

    def self.admin_fields 
        {
          id: {type: :number, edit: false},
          job_id: :lookup,
          source_name: :text,
          destination_name: :text,
          primary_key: :text,
          updated_key: :text,
          insert_only: :check_box,  #TODO: insert_only effectively becomes deprecated once copy_mode is proven, so come back and delete it
          copy_mode: :text,
          disabled: :check_box,
          run_as_separate_job: :check_box,
          time_travel_scan_back_period: :number,
          max_updated_key: {type: :text, edit: false},
          max_primary_key: {type: :text, edit: false}
        }
    end
    
    def insert_only_mode?
      if copy_mode.present?
        return copy_mode == 'INSERT_ONLY'
      else
        return insert_only
      end
    end
    
    def insert_and_update_mode?
      if copy_mode.present?
        copy_mode == 'INSERT_AND_UPDATE'
      else
        return !insert_only
      end
    end
    
    def full_data_sync_mode?
      if copy_mode.present?
        return copy_mode == 'FULL_DATA_SYNC'
      else
        return false
      end
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
            logger.warn "Aborting copy! Tables #{source_name}, #{destination_name} don't match. (job #{job_id})"
            return false
        end
        true
    end
    
    def enabled?
        if disabled
            logger.info "Aborting copy. Table #{source_name} is disabled. (job #{job_id})"
            return false
        end
        true
    end

    def source_columns
        destination_connection.columns(destination_name).map{|col| "#{source_name}.#{col.name}" }
    end

    def apply_resets
        #use this when doing a full data sync, or to rewind and catch up some data
        if full_data_sync_mode? || reset_updated_key
            rewind_time = (full_data_sync_mode? ? MIN_UPDATED_KEY : reset_updated_key)
            logger.info "Rewinding data sync on #{source_name} to #{rewind_time}"
            update_attributes({
                max_updated_key: rewind_time,
                max_primary_key: MIN_PRIMARY_KEY,
                reset_updated_key: nil
                })
        end

        if full_data_sync_mode? || delete_on_reset
            sql = "DELETE FROM #{destination_name} #{where_statement_for_source}"
            logger.info "Deleting data from #{destination_name}: #{sql}"
            destination_connection.execute(sql)
            update_attribute(:delete_on_reset, nil)
        end
    end

    def new_rows
      update_attribute(:max_updated_key, MIN_UPDATED_KEY) unless max_updated_key
      update_attribute(:max_primary_key, MIN_PRIMARY_KEY) unless max_primary_key
      
      sql = "SELECT #{source_columns.join(',')} FROM #{source_name}"
      if insert_only_mode?
        sql += " WHERE #{primary_key} > #{max_primary_key}"
        sql += " ORDER BY #{primary_key} ASC"
        sql += " LIMIT #{import_row_limit}"
      else
        sql += " WHERE ( #{updated_key} >= '#{max_updated_key.strftime('%Y-%m-%d %H:%M:%S.%N')}' AND #{primary_key} > #{max_primary_key}) OR #{updated_key} > '#{max_updated_key.strftime('%Y-%m-%d %H:%M:%S.%N')}'"
        sql += " ORDER BY #{updated_key}, #{primary_key} ASC"
        sql += " LIMIT #{import_row_limit}"
      end
      source_connection.execute(sql)
    end

    def check_for_time_travelling_data
        # If data with an older 'updated_at' is inserted into a table after newer data has been loaded it will not be picked up.
        # We can check to see if this has happened (heuristically) by looking at the count of data before the current
        # max_updated_key in both databases. If everything is normal then count of destination.updated_key will be >= count of
        # source.updated_key. Therefore if count destination.updated_key < count source.updated_key we assume that data has time
        # travelled and rewind the max_updated_key
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
      if self.respond_to?(:run_as_separate_job) && run_as_separate_job
        lock_name = "#{self.destination_name}"  # Ensure only 1 instance queued / running at a time for the destination table name!
        logger.info "Running copy of table #{source_name} as a separate job (using lock #{lock_name} for Sidekiq Unique Jobs)"
        TableWorker.perform_async(self.id, lock_name)
      else
        copied_row_count = nil
        # Run the copy_now method until there's no longer any more rows to copy
        # (ie. we're not hitting up against the impot limit)
        while !copied_row_count || copied_row_count >= import_row_limit do
          copied_row_count = copy_now
        end
      end
    end
    
    def copy_now
        started_at = Time.now
        return 0 unless (self.check && self.enabled?)
        
        logger.info "About to copy data for table #{source_name} - insert_only flag is set to [#{insert_only}] - copy_mode is set to [#{copy_mode}]"
        
        self.check_for_time_travelling_data
        self.apply_resets

        logger.info "Getting new rows for table #{source_name}"
        result = self.new_rows
        logger.info "Retrieved #{result.count} rows from #{source_name}"
        
        if result.count > 0
            logger.info "Loading #{source_name} data to Redshift"
            
            temp_table_name = "stage_#{job_id}_#{source_name}"
            destination_connection.execute("CREATE TEMP TABLE #{temp_table_name} (LIKE #{destination_name});")
            
            copy_results_to_table(temp_table_name, result)

            logger.info "Merging #{source_name} data into main table #{destination_name}"
            destination_connection.transaction do
                unless insert_only_mode?
                    logger.debug "Deleting rows which have been updated from #{destination_name} because table is not in insert only mode"
                    destination_connection.execute("DELETE FROM #{destination_name} USING #{temp_table_name} WHERE #{destination_name}.#{primary_key} = #{temp_table_name}.#{primary_key}")
                end
                logger.debug "Inserting rows into #{destination_name}"
                destination_connection.execute("INSERT INTO #{destination_name} SELECT * FROM #{temp_table_name}")
            end

            #update max_updated_at and max_primary_key
            x = destination_connection.execute("SELECT MAX(#{primary_key}) as max_primary_key, MAX(#{updated_key}) as max_updated_key
                FROM #{temp_table_name} WHERE #{updated_key} = (SELECT MAX(#{updated_key}) FROM #{temp_table_name})").first

            logger.info "Max updated_key for #{source_name} is now #{x['max_updated_key']}"
            update_attributes({
                max_primary_key: x['max_primary_key'].to_i,
                max_updated_key: x['max_updated_key']
                })

            destination_connection.execute("DROP TABLE #{temp_table_name};")
        end

        #Log for benchmarking
        finished_at = Time.now
        logger.info "Total time taken to copy #{result.count} rows from #{source_name} to #{destination_name} was #{finished_at - started_at} seconds"
        self.table_copies << TableCopy.create(text: "Copied #{source_name} to #{destination_name}", rows_copied: result.count, started_at: started_at, finished_at: finished_at)

        # Return the result count to the caller
        return result.count
    end
    
    
    def copy_results_to_table(table_name, results)
      if ENV['PARALLEL_PROCESSING_NODE_SLICES']
        
        # Parallel processing version - create all files first, then load into table in parallel.
        # See http://docs.aws.amazon.com/redshift/latest/dg/t_Loading-data-from-S3.html
        # and http://docs.aws.amazon.com/redshift/latest/dg/loading-data-files-using-manifest.html
        
        file_prefix = "#{job_id}_#{source_name}_#{Time.now.to_i}"
        filenames = []
        
        # Don't bother with chunk size < 1000
        chunk_size = [ (results.count.to_f / ENV['PARALLEL_PROCESSING_NODE_SLICES'].to_i).ceil, 1000].max
        
        results.each_slice(chunk_size).with_index do |slice, i|
          filename = "#{file_prefix}.txt.#{i+1}"
          logger.info " - Copying chunk #{i+1} of #{source_name} data to S3 (#{filename})"
          csv_string = CSV.generate do |csv|
            slice.each do |row|
              csv << row.values
            end
          end
          
          filenames << filename
          text_file = bucket.objects.build(filename)
          text_file.content = csv_string
          text_file.save
        end
        
        # Create the manifest, listing all the data files
        manifest_content = { "entries" => [] }
        filenames.each { |f|  manifest_content["entries"] << { "url" => "s3://#{bucket_name}/#{f}", "mandatory" => true }  }
        manifest_filename = "#{file_prefix}.manifest"
        manifest_file = bucket.objects.build(manifest_filename)
        manifest_file.content = manifest_content.to_json
        manifest_file.save

        logger.info "Copying all chunks of #{source_name} data from S3 to Redshift"
        # Import the data to Redshift
        destination_connection.execute("COPY #{table_name} from 's3://#{bucket_name}/#{manifest_filename}' 
            credentials 'aws_access_key_id=#{ENV['AWS_ACCESS_KEY_ID']};aws_secret_access_key=#{ENV['AWS_SECRET_ACCESS_KEY']}' delimiter ',' CSV QUOTE AS '\"'  manifest;")
        
        manifest_file.destroy
        
        filenames.each do |f|
          logger.info " - Deleting chunk of #{source_name} data from S3 (#{f})"
          bucket.objects.find(f).destroy
        end
        
      else
        
        # Non-parallel processing version - create then load one file at a time
        results.each_slice(import_chunk_size) do |slice|
          logger.info " - Copying chunk of #{source_name} data to S3"
          csv_string = CSV.generate do |csv|
            slice.each do |row|
              csv << row.values
            end
          end

          filename = "#{job_id}_#{source_name}_#{Time.now.to_i}.txt"
          text_file = bucket.objects.build(filename)
          text_file.content = csv_string
          text_file.save

          logger.info " - Copying chunk of #{source_name} data from S3 to Redshift"
          # Import the data to Redshift
          destination_connection.execute("COPY #{table_name} from 's3://#{bucket_name}/#{filename}' 
              credentials 'aws_access_key_id=#{ENV['AWS_ACCESS_KEY_ID']};aws_secret_access_key=#{ENV['AWS_SECRET_ACCESS_KEY']}' delimiter ',' CSV QUOTE AS '\"' ;")

          logger.info " - Deleting chunk of #{source_name} data from S3"
          text_file.destroy
        end
        
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
