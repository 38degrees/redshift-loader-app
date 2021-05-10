module DbConnection
  # For now create a new SourceDb / DestinationDb class for each job and set it up each time the job runs.
  # This should allow parallel processing of multiple jobs at the same time without connection reset errors.
  #
  # In future, once we've established this stuff works reliably in Prod, it would be good to setup a
  # "connections" table in the redshift-loader DB and replace the jobs.source_connection_string and
  # jobs.destination_connection_string columns with references to a "connections" table. This way we
  # could share connections (using connection pools) to the same DBs across multiple jobs, and probably
  # also get away without re-establishing the connection everytime a job starts.

  def setup_connection(job_id, connection_string)
    klass = get_connection_klass(job_id)
    klass.establish_connection(connection_string)
  end

  def get_connection(job_id)
    klass = get_connection_klass(job_id)
    klass.connection
  end

  # Dynamically get or build a Class for this Jobs DB Connection
  # (establishing ActiveRecord connections seemingly requires a entirely new class per connection!)
  def get_connection_klass(job_id)
    class_name = "#{name}ForJob#{job_id}"

    unless Object.const_defined?(class_name)
      logger.info "Constructing new class for database connections, with class name #{class_name}"
      Object.const_set(class_name, Class.new(self))
    end

    Object.const_get(class_name)
  end
end
