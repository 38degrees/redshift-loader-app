# Redshift Loader App
Easily deployable to Heroku/Dokku etc. ruby app to incrementally load data from multiple postgres tables into redshift in order to keep a near-realtime replica of your production database for analytics. 

Currently it supports copying insert-only tables with an auto-increment or sequential primary key and copying upsert-only (no delete) tables with an 'updated_at' column.

# Getting started

Deploy the app and set environment variables. Run rake db:migrate and rake db:seed to set up the database and an admin user.

Log in to '/admin' with the credentials you just created.

Each pair of postgres database and redshift database is called a 'Job'. Each job has multiple tables which specify tables to be copied, primary_keys, updated_keys and whether the table is insert_only.

Create a new job , then specify a source_connection_string and destination_connection_string.

You can run Job.find(x).setup to extract all tables in the source database (public schema) and create them in the destination database (public schema). This will attempt to set primary_key and updated_key for each of the tables, but you will likely need to check and adjust details after you're run 'setup'.

The app uses Clockwork (https://github.com/tomykaira/clockwork) in order to regularly run the import job. In order to set up a regular import job create a new ClockworkEvent with the statement 'Job.find(x).run' at your chosen frequency (in seconds).

