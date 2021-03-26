return if ENV['AIRBRAKE_PROJECT_ID'].nil?

# :nocov:
Padrino.before_load do
  require 'airbrake'
  Airbrake.configure do |config|
    config.project_id = ENV['AIRBRAKE_PROJECT_ID']
    config.project_key = ENV['AIRBRAKE_PROJECT_KEY']

    config.host = ENV['AIRBRAKE_HOST'] if ENV['AIRBRAKE_HOST']

    config.blocklist_keys = ['password']

    config.root_directory = Padrino.root
    config.environment = Padrino.env
    config.ignore_environments = [:test]
  end

  Airbrake.add_filter do |notice|
    notice.ignore! if notice.stash[:exception].is_a?(Sinatra::NotFound)
  end
end
# :nocov:
