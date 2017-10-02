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
    "ORDER BY #{updated_key}, #{primary_key} ASC"
  end
  
  def check_for_time_travelling_data
    # If data with an older 'updated_at' is inserted into a table after newer data has been loaded it will not be picked up.
    # We can check to see if this has happened (heuristically) by looking at the count of data before the current
    # max_updated_key in both databases. If everything is normal then count of destination.updated_key will be >= count of
    # source.updated_key. Therefore if count destination.updated_key < count source.updated_key we assume that data has time
    # travelled and rewind the max_updated_key
    if time_travel_scan_back_period
      sql = "SELECT COUNT(*) as count FROM #{destination_name}
             WHERE #{updated_key} >= '#{max_updated_key - time_travel_scan_back_period}'
             AND #{updated_key} < '#{max_updated_key}'"
      destination_count = destination_connection.execute(sql).first['count'].to_i

      sql = "SELECT COUNT(*) as count FROM #{source_name}
             WHERE #{updated_key} >= '#{max_updated_key - time_travel_scan_back_period}'
             AND #{updated_key} < '#{max_updated_key}'"
      source_count = source_connection.execute(sql).first['count'].to_i

      if source_count > destination_count
        update_attribute(:reset_updated_key, max_updated_key - time_travel_scan_back_period)
      end
    end
  end
  
  def update_max_values(table_name = self.destination_name)
    sql = "SELECT MAX(#{primary_key}) as max_primary_key,
                  MAX(#{updated_key}) as max_updated_key
           FROM #{table_name}"
    x = destination_connection.execute(sql).first

    logger.info "max_primary_key is now #{x['max_primary_key']} and max_updated_key is now #{x['max_updated_key']} for #{source_name}"
    update_attributes({
        max_primary_key: x['max_primary_key'].to_i,
        max_updated_key: x['max_updated_key']
        })
  end
  
end
