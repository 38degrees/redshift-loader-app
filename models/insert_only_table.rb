class InsertOnlyTable < Table
  # InsertOnlyTable is for tables where data is never updated after being inserted
  # OR where even if a record was updated after insertion, we don't care about
  # copying across the updates to the record.
  
  
  def where_statement_for_source
    # For InsertOnlyTables we assume rows are never updated in the source DB after
    # creation (and/or if they are, we don't care about copying the updates across!)
    # So we simply look for records with a higher primary_key
    "WHERE #{primary_key} > #{max_primary_key}"
  end
  
  def order_by_statement_for_source
    "ORDER BY #{primary_key} ASC"
  end
  
  def check_for_time_travelling_data
    if time_travel_scan_back_period
      logger.warn "time_travel_scan_back_period is not supported for #{source_name} because it is an InsertOnlyTable"
    end
  end
  
  def update_max_values(table_name = self.destination_name)
    # For InsertOnlyTables we don't set the value of the max_updated_key because we don't
    # use it to select new rows, and if the table type switched to UpdateAndInsert it would
    # need to scan *all* records for more recently updated rows!
    sql = "SELECT MAX(#{primary_key}) as max_primary_key
           FROM #{table_name}"
    x = destination_connection.execute(sql).first

    logger.info "max_primary_key is now #{x['max_primary_key']} for #{source_name}"
    update_attributes({ max_primary_key: x['max_primary_key'].to_i })
  end
  
end
