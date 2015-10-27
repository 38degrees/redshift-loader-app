class SourceDb < ActiveRecord::Base
    self.abstract_class = true
    self.table_name = "B"
end