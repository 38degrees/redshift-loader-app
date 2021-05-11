RedshiftLoaderApp::Admin.controllers :sessions do
  get :new do
    render "/sessions/new", nil, layout: false
  end

  post :create do
    account = Account.authenticate(params[:email], params[:password])
    if account
      set_current_account(account)
      redirect url(:base, :index)
    elsif Padrino.env == :development && params[:bypass]
      account = Account.first
      set_current_account(account)
      redirect url(:base, :index)
    else
      params[:email] = h(params[:email])
      flash.now[:error] = pat('login.error')
      render "/sessions/new", nil, layout: false
    end
  end

  delete :destroy do
    set_current_account(nil)
    redirect url(:sessions, :new)
  end
end
