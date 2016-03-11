RedshiftLoaderApp::App.controller do
    get '/table_copies' do
      sign_in_required!
      @table_copies = TableCopy.all.order("updated_at DESC").limit(100)
      erb :table_copies
    end
end
