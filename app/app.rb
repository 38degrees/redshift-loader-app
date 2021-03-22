module RedshiftLoaderApp
  class App < Padrino::Application
    use ConnectionPoolManagement
    use Airbrake::Rack::Middleware if ENV['AIRBRAKE_PROJECT_ID']

    register Padrino::Mailer
    register Padrino::Helpers

    enable :sessions
  end
end
