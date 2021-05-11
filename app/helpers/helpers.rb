RedshiftLoaderApp::App.helpers do
  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end

  def sign_in_required!
    return if current_account

    flash[:notice] = I18n.t("app.helpers.helpers.sign_in_required_msg")
    session[:return_to] = request.url
    request.xhr? ? halt : redirect('/admin')
  end
end
