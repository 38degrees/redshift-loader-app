require 'net/http'

RedshiftLoaderApp::App.helpers do

  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end

  def sign_in_required!
    unless current_account
      flash[:notice] = I18n.t("app.helpers.helpers.sign_in_required_msg")
      session[:return_to] = request.url
      request.xhr? ? halt : redirect('/admin')
    end
  end

  def post_warning(message)
    logger.warn message
    post_to_slack message
  end

  def post_to_slack(message)
    if ENV['SLACK_URL']
      uri = URI.parse(ENV['SLACK_URL'])
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri, {'Content-Type' => 'text/json'})
      request.body = {text: message}.to_json
      https.request(request)
    end
  end

end
