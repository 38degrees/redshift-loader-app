require_relative '../../lib/sidekiq/clear_active_connections'
require 'sidekiq-unique-jobs'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }

  config.logger.level = Logger.const_get((ENV['LOG_LEVEL'] || 'info').upcase)

  config.server_middleware do |chain|
    chain.add Sidekiq::ClearActiveConnections
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end
