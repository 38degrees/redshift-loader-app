require_relative '../../lib/sidekiq/clear_active_connections'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
  config.server_middleware do |chain|
    chain.add Sidekiq::ClearActiveConnections
  end
end

Sidekiq::Logging.logger.level = Logger.const_get((ENV['LOG_LEVEL'] || 'info').upcase)
