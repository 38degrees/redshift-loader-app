Padrino.before_load do
  if ENV['SENTRY_DSN']
    require 'sentry-ruby'
    require 'sentry-sidekiq'

    Sentry.init do |config|
      config.dsn = ENV['SENTRY_DSN']
    end

    Padrino.use Sentry::Rack::CaptureExceptions
  end
end
