# workers.rb
# runs sidekiq workers
require File.expand_path('boot.rb', __dir__)
Dir[File.expand_path('../app/workers/**/*.rb', __dir__)].each { |file| require file }
