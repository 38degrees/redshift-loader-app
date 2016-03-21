RedshiftLoaderApp::App.controller do
  get '/tables' do
    @tables = Table.all.includes(:table_copies).order("tables.source_name")
    erb :tables
  end

  post '/tables/:id/reset' do
    datetime = DateTime.parse(params[:datetime])
    table = Table.find(params[:id])
    table.update_attribute(:reset_updated_key, datetime)
    redirect back
  end
end
