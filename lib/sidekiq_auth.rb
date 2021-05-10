module RedshiftLoader
  class SidekiqAuth
    def initialize(app)
      @app = app
    end

    def call(env)
      session = env['rack.session']
      forbidden = [403, { 'Content-Type' => 'text/html' }, ['You must be logged in to Redshift-Loader']]

      if RACK_ENV != 'development'
        return forbidden if session[:account_id].nil?

        current_account = Account.find(session[:account_id]) if session[:account_id]

        return forbidden if current_account.nil? || !current_account.admin?
      end

      @app.call(env)
    end
  end
end
