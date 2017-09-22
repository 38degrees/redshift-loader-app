# workers.rb
# runs sidekiq workers
require File.expand_path('../boot.rb', __FILE__)
Dir[File.expand_path('../../app/workers/**/*.rb', __FILE__)].each { |file| require file }
