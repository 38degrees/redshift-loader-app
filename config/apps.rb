Padrino.configure_apps do
  # enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
  set :protection, except: :path_traversal
  set :protect_from_csrf, true
end

# Mounts the core application for this project
Padrino.mount('ActivateAdmin::App', app_file: ActivateAdmin.root('app/app.rb')).to('/admin')
Padrino.mount('RedshiftLoaderApp::App', app_file: Padrino.root('app/app.rb')).to('/')
