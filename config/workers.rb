# workers.rb
# runs sidekiq workers
require File.expand_path('boot.rb', __dir__)
Dir[File.expand_path('../app/workers/**/*.rb', __dir__)].sort.each { |file| require file }
