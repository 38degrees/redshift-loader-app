# Defines our constants
RACK_ENV = ENV['RACK_ENV'] ||= 'development' unless defined?(RACK_ENV)
PADRINO_ROOT = File.expand_path('..', __dir__) unless defined?(PADRINO_ROOT)

# Load our dependencies
require 'bundler/setup'
Bundler.require(:default, RACK_ENV)

# Make sure logs aren't buffered
Padrino::Logger::Config[:production][:log_level] = (ENV['LOG_LEVEL'] || 'info').downcase.to_sym
Padrino::Logger::Config[:production][:auto_flush] = :true
Padrino::Logger::Config[:production][:stream] = :stdout

##
# Add your before (RE)load hooks here
#
Padrino.before_load do
  # pass
end

##
# Add your after (RE)load hooks here
#
Padrino.after_load do
  # pass
end

Padrino.load!

Padrino.require_dependencies "#{Padrino.root}/config/initializers/**/*.rb"
require Padrino.root('config', 'workers.rb')
