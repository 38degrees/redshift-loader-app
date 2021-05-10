class SourceDb < ActiveRecord::Base
  extend DbConnection

  self.abstract_class = true
  self.table_name = "B"
end
