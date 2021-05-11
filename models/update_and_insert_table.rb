class UpdateAndInsertTable < Table
  # UpdateAndInsertTable is for tables where we want to copy over both new rows
  # AND rows which have been updated.
  #
  # NOTE: it is assumed that the updated_key (usually the updated_at ActiveRecord
  # column) is updated every time a record changes. If you manually update a
  # record (eg. by directly connecting to the source database) and forget to update
  # the update_key, the updates to the row WILL NOT BE COPIED ACROSS!

  def where_statement_for_source
    # For UpdateAndInsertTables we want to find all rows which have been updated
    # more recently than the last time we ran. Because each run picks up a limited
    # number of rows (import_row_limit), it's possible we also missed some rows
    # with the same updated_key, but a higher primary_key, so also look for those
    "WHERE ( #{updated_key} >= '#{max_updated_key.strftime('%Y-%m-%d %H:%M:%S.%N')}' AND #{primary_key} > #{max_primary_key} )
     OR #{updated_key} > '#{max_updated_key.strftime('%Y-%m-%d %H:%M:%S.%N')}'"
  end

  def order_by_statement_for_source
    # See comment on update_max_values to understand why ordering by both updated_key *and* primary_key are important...
    "ORDER BY #{updated_key}, #{primary_key} ASC"
  end

  def check_for_time_travelling_data
    # If data with an older 'updated_at' is inserted into a table after newer data has been loaded it will not be picked up.
    # We can check to see if this has happened (heuristically) by looking at the count of data before the current
    # max_updated_key in both databases. If everything is normal then count of destination.updated_key will be >= count of
    # source.updated_key. Therefore if count destination.updated_key < count source.updated_key we assume that data has time
    # travelled and rewind the max_updated_key
    return unless time_travel_scan_back_period

    sql = "SELECT COUNT(*) as count FROM #{destination_name}
            WHERE #{updated_key} >= '#{max_updated_key - time_travel_scan_back_period}'
            AND #{updated_key} < '#{max_updated_key}'"
    destination_count = destination_connection.execute(sql).first['count'].to_i

    sql = "SELECT COUNT(*) as count FROM #{source_name}
            WHERE #{updated_key} >= '#{max_updated_key - time_travel_scan_back_period}'
            AND #{updated_key} < '#{max_updated_key}'"
    source_count = source_connection.execute(sql).first['count'].to_i

    update_attribute(:reset_updated_key, max_updated_key - time_travel_scan_back_period) if source_count > destination_count
  end

  def update_max_values(table_name = destination_name)
    # Why are we selecting the max primary_key only considering those records that happen to have the max updated_key?
    # Because we need to ensure that when selecting new rows we'll pickup rows that have the *same* updated_key and a
    # higher primary_key, *not just* those that have a higher updated_key.
    #
    # Consider the following example:
    # primary_key | updated_key
    #        1001 | 2015-01-01
    #        1002 | 2017-01-02
    #        1003 | 2017-01-02
    #        1004 | 2017-01-01
    #
    # If the import_row_limit was set to 1, and the job is run for the first time since records 1002 & 1003 were last
    # updated, then the job will find record 1002 and update it (it will order 1002 before 1003 - see the ORDER BY clause
    # which orders by updated_key and then by primary_key). Next run it needs to find record 1003. Using the WHERE clause
    # above, 1003 does not have an updated_key which is strictly greater than 1002's (2017-01-02), but it *does* have an
    # equal updated_key and greater primary_key. So it's important we use the MAX primary_key, only considering those
    # with the MAX updated_key for UpdateAndInsertTable. If we used the MAX primary_key of the whole table, we would miss
    # this update of row 1003.

    sql = "SELECT MAX(#{primary_key}) as max_primary_key, MAX(#{updated_key}) as max_updated_key
                  FROM #{table_name} WHERE #{updated_key} = (SELECT MAX(#{updated_key}) FROM #{table_name})"
    x = destination_connection.execute(sql).first

    logger.info "max_primary_key is now #{x['max_primary_key']} and max_updated_key is now #{x['max_updated_key']} for #{source_name}"
    update_attributes({
                        max_primary_key: x['max_primary_key'].to_i,
                        max_updated_key: x['max_updated_key']
                      })
  end
end
