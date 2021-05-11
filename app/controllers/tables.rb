RedshiftLoaderApp::App.controller do
  before do
    sign_in_required!
  end

  get '/tables' do
    @tables = Table.all.order("tables.source_name")
    erb :tables
  end

  post '/tables/:id/reset' do
    datetime = DateTime.parse(params[:datetime])
    delete_on_reset = params[:delete_on_reset].present?
    table = Table.find(params[:id])
    table.update_attribute(:reset_updated_key, datetime)
    table.update_attribute(:delete_on_reset, delete_on_reset)
    redirect back
  end
end
