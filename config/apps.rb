Padrino.configure_apps do
  # enable :sessions
  set :session_secret, '847e4d75e54137db7cd5e54757383dafa315b97d21a371585f1306e8a36c1c76'
  set :protection, :except => :path_traversal
  set :protect_from_csrf, true
end

# Mounts the core application for this project
Padrino.mount('ActivateAdmin::App', :app_file => ActivateAdmin.root('app/app.rb')).to('/admin')
Padrino.mount('RedshiftLoaderApp::App', :app_file => Padrino.root('app/app.rb')).to('/')


