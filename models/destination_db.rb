class DestinationDb < ActiveRecord::Base
  extend DbConnection

  self.abstract_class = true
  self.table_name = "A"
end
