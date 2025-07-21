require_relative '../../lib/sidekiq/clear_active_connections'
require "sidekiq-unique-jobs"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }

  config.logger.level = Logger.const_get( (ENV['LOG_LEVEL'] || 'info').upcase )

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
    chain.add Sidekiq::ClearActiveConnections
  end

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  SidekiqUniqueJobs::Server.configure(config)
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end