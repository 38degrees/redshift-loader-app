require 'net/http'

class Table < ActiveRecord::Base
  MIN_UPDATED_KEY = '1970-01-01'.freeze
  MIN_PRIMARY_KEY = 0

  belongs_to :job
  has_many :table_copies

  self.inheritance_column = 'table_copy_type'

  def self.admin_fields
    {
      id: { type: :number, edit: false },
      job_id: :lookup,
      source_name: :text,
      destination_name: :text,
      primary_key: :text,
      updated_key: :text,
      # TODO: insert_only and copy_mode are deprecated! Delete altogether later...
      # insert_only: :check_box,
      # copy_mode: :text,
      table_copy_type: :text,
      disabled: :check_box,
      run_as_separate_job: :check_box,
      time_travel_scan_back_period: :number,
      max_updated_key: { type: :text, edit: false },
      max_primary_key: { type: :text, edit: false }
    }
  end

  def source_connection
    job.source_connection
  end

  def destination_connection
    job.destination_connection
  end

  # rough-n-ready check if the tables have the same columns
  def check
    source_columns = source_connection.columns(source_name).map(&:name)
    destination_columns = destination_connection.columns(destination_name).map(&:name)
    unless source_columns.sort == destination_columns.sort
      post_warning "Aborting copy! Tables #{source_name}, #{destination_name} don't match. (job #{job_id})"
      return false
    end
    true
  end

  def enabled?
    if disabled
      logger.warn "Aborting copy. Table #{source_name} is disabled. (job #{job_id})"
      return false
    end
    true
  end

  def source_columns
    destination_connection.columns(destination_name).map { |col| "#{source_name}.#{col.name}" }
  end

  def apply_resets
    # use this to rewind and catch up some data
    if reset_updated_key
      rewind_time = reset_updated_key
      logger.info "Rewinding data sync on #{source_name} to #{rewind_time}"
      update_attributes({
                          max_updated_key: rewind_time,
                          max_primary_key: MIN_PRIMARY_KEY,
                          reset_updated_key: nil
                        })
    end

    return unless delete_on_reset

    sql = "DELETE FROM #{destination_name} #{where_statement_for_source}"
    logger.info "Deleting data from #{destination_name}: #{sql}"
    destination_connection.execute(sql)
    update_attribute(:delete_on_reset, nil)
  end

  def where_statement_for_source
    raise NotImplementedError, "#{self.class.name}#where_statement_for_source is an abstract method."
  end

  def order_by_statement_for_source
    raise NotImplementedError, "#{self.class.name}#order_by_statement_for_source is an abstract method."
  end

  def new_rows
    sql = "SELECT #{source_columns.join(',')} FROM #{source_name}
             #{where_statement_for_source}
             #{order_by_statement_for_source}
             LIMIT #{import_row_limit}"
    source_connection.execute(sql)
  end

  def check_for_time_travelling_data
    raise NotImplementedError, "#{self.class.name}#check_for_time_travelling_data is an abstract method."
  end

  def copy
    if respond_to?(:run_as_separate_job) && run_as_separate_job
      lock_name = destination_name.to_s # Ensure only 1 instance queued / running at a time for the destination table name!
      logger.info "Running copy of table #{source_name} as a separate job (using lock #{lock_name} for Sidekiq Unique Jobs)"
      TableWorker.perform_async(id, lock_name)
    else
      copied_row_count = nil
      # Run the copy_now method until there's no longer any more rows to copy
      # (ie. we're not hitting up against the impot limit)
      copied_row_count = copy_now while !copied_row_count || copied_row_count >= import_row_limit
    end
  end

  def copy_now
    started_at = Time.now
    return 0 unless enabled? && check

    logger.info "About to copy data for table #{source_name} - table_copy_type is #{table_copy_type}, using class #{self.class.name}"

    pre_copy_steps

    check_for_time_travelling_data
    apply_resets

    # Ensure max keys are not nil
    update_attribute(:max_updated_key, MIN_UPDATED_KEY) unless max_updated_key
    update_attribute(:max_primary_key, MIN_PRIMARY_KEY) unless max_primary_key

    logger.info "Getting new rows for table #{source_name}"
    result = new_rows
    logger.info "Retrieved #{result.count} rows from #{source_name}"

    if result.count.positive?
      logger.info "Loading #{source_name} data to Redshift"

      temp_table_name = "stage_#{job_id}_#{source_name}"
      destination_connection.execute("CREATE TEMP TABLE #{temp_table_name} (LIKE #{destination_name});")

      copy_results_to_table(temp_table_name, result)
      merge_results(temp_table_name, merge_to_table_name)
      update_max_values(temp_table_name)

      destination_connection.execute("DROP TABLE #{temp_table_name};")
    end

    # Log for benchmarking
    finished_at = Time.now
    logger.info "Total time taken to copy #{result.count} rows from #{source_name} to #{merge_to_table_name} was #{finished_at - started_at} seconds"
    table_copies << TableCopy.create(text: "Copied #{source_name} to #{merge_to_table_name}", rows_copied: result.count, started_at: started_at, finished_at: finished_at)

    post_copy_steps(result)

    # Return the result count to the caller
    result.count
  end

  def copy_results_to_table(table_name, results)
    dest_col_limits = get_destination_column_limits

    if ENV['COPY_VIA_S3'] && ENV['PARALLEL_PROCESSING_NODE_SLICES']

      # Parallel processing version - create all files first, then load into table in parallel.
      # See http://docs.aws.amazon.com/redshift/latest/dg/t_Loading-data-from-S3.html
      # and http://docs.aws.amazon.com/redshift/latest/dg/loading-data-files-using-manifest.html

      file_prefix = "#{job_id}_#{source_name}_#{Time.now.to_i}"
      filenames = []

      # Don't bother with chunk size < 1000
      chunk_size = [(results.count.to_f / ENV['PARALLEL_PROCESSING_NODE_SLICES'].to_i).ceil, 1000].max

      results.each_slice(chunk_size).with_index do |slice, i|
        filename = "#{file_prefix}.txt.#{i + 1}"
        logger.info " - Copying chunk #{i + 1} of #{source_name} data to S3 (#{filename})"
        csv_string = CSV.generate do |csv|
          slice.each do |row|
            truncate_row_values!(row, dest_col_limits)
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
      filenames.each { |f| manifest_content["entries"] << { "url" => "s3://#{bucket_name}/#{f}", "mandatory" => true } }
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

    elsif ENV['COPY_VIA_S3']

      # Non-parallel processing version - create then load one file at a time
      results.each_slice(import_chunk_size) do |slice|
        logger.info " - Copying chunk of #{source_name} data to S3"
        csv_string = CSV.generate do |csv|
          slice.each do |row|
            truncate_row_values!(row, dest_col_limits)
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

    else

      # Mainly for use in dev so we don't need to use S3 & redshift
      results.each_slice(import_chunk_size) do |slice|
        logger.info " - Copying chunk of #{source_name} data direct to #{table_name}"
        columns = destination_connection.columns(destination_name).map { |col| col.name.to_s }.join(',')
        slice.each do |row|
          truncate_row_values!(row, dest_col_limits)
          destination_connection.execute("INSERT INTO #{table_name} (#{columns}) VALUES ('#{row.values.join("','")}');")
        end
      end

    end
  end

  def merge_results(from_table_name, to_table_name = destination_name)
    logger.info "Merging #{source_name} data into main table #{to_table_name}"
    destination_connection.transaction do
      # Previously the delete didn't occur for insert only tables, but it should be quick and provides
      # protection from duplicates incase of manual manipulation of the max PK, etc.
      logger.debug "Deleting any rows from #{to_table_name} which would create duplicates"
      destination_connection.execute("DELETE FROM #{to_table_name} USING #{from_table_name} WHERE #{to_table_name}.#{primary_key} = #{from_table_name}.#{primary_key}")

      logger.debug "Inserting rows into #{to_table_name}"
      destination_connection.execute("INSERT INTO #{to_table_name} SELECT * FROM #{from_table_name}")
    end
  end

  def update_max_values(_table_name = destination_name)
    # Update max_updated_at and max_primary_key to the max values from the given table
    # Default to the destination table itself, but also allow passing in a temp table,
    # as this will contain less rows and should be quicker)

    raise NotImplementedError, "#{self.class.name}#update_max_values is an abstract method."
  end

  def pre_copy_steps
    # Empty by default
  end

  def post_copy_steps(result)
    # Empty by Default
  end

  def merge_to_table_name
    # Default to the destination table
    destination_name
  end

  def import_row_limit
    ENV['IMPORT_ROW_LIMIT'] ? ENV['IMPORT_ROW_LIMIT'].to_i : 100_000
  end

  def import_chunk_size
    ENV['IMPORT_CHUNK_SIZE'] ? ENV['IMPORT_CHUNK_SIZE'].to_i : 10_000
  end

  def s3
    S3::Service.new(access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])
  end

  def bucket_name
    ENV['S3_BUCKET_NAME']
  end

  def bucket
    s3.buckets.find(bucket_name)
  end

  def get_destination_column_limits
    return {} unless ENV['AUTO_TRUNCATE_COLUMNS']

    limits_hash = destination_connection.columns(destination_name).each_with_object({}) do |col, limits_hash|
      limits_hash[col.name] = col.limit if col.sql_type.starts_with?("character varying") && col.limit
    end

    logger.info "The following columns of #{destination_name} will be truncated: #{limits_hash}"
    limits_hash
  end

  def truncate_row_values!(row, dest_col_limits)
    return unless ENV['AUTO_TRUNCATE_COLUMNS']

    row.each do |col, value|
      if dest_col_limits[col] && value.is_a?(String) && value.length > dest_col_limits[col]
        row[col] = value.truncate(dest_col_limits[col], omission: '')
        logger.warn "Truncated column #{col} of row #{primary_key}=#{row[primary_key]} because it was too long (#{value.length} vs max of #{dest_col_limits[col]} in destination DB)"
      end
    end
  end

  # This method should live elsewhere, putting here as a quick fix!
  def post_warning(message)
    logger.warn message
    post_to_slack message
  end

  # This method should live elsewhere, putting here as a quick fix!
  def post_to_slack(message)
    return unless ENV['SLACK_URL']

    uri = URI.parse(ENV['SLACK_URL'])
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'text/json' })
    request.body = { text: "*RedshiftLoader:* #{message}" }.to_json
    https.request(request)
  end
end
