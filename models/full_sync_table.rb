class FullSyncTable < Table
  # FullSyncTable is for tables where we want to periodically do a full copy of
  # the source table. The main use-case for this is where it is important to copy
  # over the fact that rows have been deleted from the source database. Detecting
  # deletions is not possible with either InsertOnlyTable or UpdateAndInsertTable.
  #
  # NOTE: While InsertOnlyTable and UpdateAndInsertTable incrementally keep the
  # destination table up to date, FullSyncTable incrementally builds up a complete
  # replacement table, and when complete swaps it out for the original, and then
  # starts the whole process again.
  #
  # Eg. Assume initially we have a populated destination table.
  # When the copy job runs for FullSyncTable, it will check if a table called
  # "full_sync_swap_table_#{destination_name}" exists. If not, this will be
  # created, and rows will be incrementally copied over to this table. When a
  # run of the copy job detects that all rows have been copied to the swap
  # table, it will swap out the existing table for the swap table in a
  # transaction. Next time the copy job runs, the swap table will not be present,
  # so will be re-created, and the cycle starts again.
  #
  # This means that the value of max_updated_key reflects the current max
  # primary key of the SWAP table - this will cycle depending upon how far the
  # current full table sync is through the copy process. This also means that
  # if changing the type of a table from FullSyncTable to one of the other
  # types, you are strongly advised to manually set the max_primary_key and
  # max_updated_key at the same time as changing the type or risk duplicate
  # and/or missing rows!

  def where_statement_for_source
    # For FullSyncTable, rows might be updated or deleted, but this will be picked
    # up on the next iteration of re-building the swap table, so only care about
    # finding actual new rows here.
    "WHERE #{primary_key} > #{max_primary_key}"
  end

  def order_by_statement_for_source
    "ORDER BY #{primary_key} ASC"
  end

  def apply_resets
    logger.warn "reset_updated_key is not supported for #{source_name} because it is a FullSyncTable" if reset_updated_key || delete_on_reset
  end

  def check_for_time_travelling_data
    logger.warn "time_travel_scan_back_period is not supported for #{source_name} because it is a FullSyncTable" if time_travel_scan_back_period
  end

  def update_max_values(table_name = destination_name)
    sql = "SELECT MAX(#{primary_key}) as max_primary_key
           FROM #{table_name}"
    x = destination_connection.execute(sql).first

    logger.info "max_primary_key is now #{x['max_primary_key']} for #{source_name}"
    update_attributes({ max_primary_key: x['max_primary_key'].to_i })
  end

  def swap_table_name
    "full_sync_swap_table_#{destination_name}"
  end

  def old_table_name
    "full_sync_old_table_#{destination_name}"
  end

  def pre_copy_steps
    # Need to ensure the swap table is created before any copying
    destination_connection.execute("CREATE TABLE IF NOT EXISTS #{swap_table_name} (LIKE #{destination_name});")
  end

  def post_copy_steps(result)
    # Check if all data is copied to the swap table. If so, replace the original table with the now up-to-date swap.
    # Also delete the old version of the table if exists, and rename the current version to old (because dropping the
    # current version immediately will break currently executing queries, renaming to old will let them complete).
    return if result.count >= import_row_limit

    logger.info "Swap table #{swap_table_name} has all data from #{source_name}, renaming #{destination_name} to #{old_table_name} and renaming #{swap_table_name} to #{destination_name}"
    sql  = "BEGIN;"
    sql += "GRANT SELECT ON #{swap_table_name} TO #{ENV['READ_ONLY_USERS']};" if ENV['READ_ONLY_USERS']
    sql += "DROP TABLE IF EXISTS #{old_table_name};"
    sql += "ALTER TABLE #{destination_name} RENAME TO #{old_table_name};"
    sql += "ALTER TABLE #{swap_table_name} RENAME TO #{destination_name};"
    sql += "END;"
    destination_connection.execute(sql)

    # Completed a full copy cycle, so reset the keys so we start again from scratch on the next run
    update_attribute(:max_updated_key, MIN_UPDATED_KEY)
    update_attribute(:max_primary_key, MIN_PRIMARY_KEY)
  end

  def merge_to_table_name
    # For FullSyncTable we want to merge results into the swap table, which will be switched later
    # (see the post_copy_steps method)
    swap_table_name
  end
end
