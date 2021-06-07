return unless ENV['SENTRY_DSN']

require 'sentry-ruby'
require 'sentry-sidekiq'

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
end
