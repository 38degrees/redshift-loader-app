# Redshift Loader App
Easily deployable to Heroku/Dokku etc. ruby app to incrementally load data from multiple postgres tables into redshift in order to keep a near-realtime replica of your production database for analytics. 

It can copy your schema from Postgres to Redshift, perform an initial data load and then keep it up-to-date with changes as long as your tables are either insert-only with a sequential primary key, or have an `updated_at` column with is indexed.

# Getting started

Deploy the app and set environment variables. Run rake db:migrate and rake db:seed to set up the database and an admin user.

Log in to '/admin' with the credentials you just created.

Each pair of postgres database and redshift database is called a 'Job'. Each job has multiple tables which specify tables to be copied, primary_keys, updated_keys and whether the table is insert_only.

Create a new job, then specify a source_connection_string and destination_connection_string.

You can run `Job.find(x).setup` to extract all tables in the source database (public schema) and create them in the destination database (public schema). This will attempt to set `primary_key` and `updated_key` for each of the tables, but you will likely need to check and adjust details after you've run 'setup'.

The app uses Clockwork (https://github.com/tomykaira/clockwork) in order to regularly run the import job. In order to set up a regular import job create a new ClockworkEvent with the statement `Job.find(x).run` at your chosen frequency (in seconds).

`.run` is suitable for the intial data load and for incremental loading. It uses the environment variables `IMPORT_ROW_LIMIT` and `IMPORT_CHUNK_SIZE` to determine how much data to copy in one go, but if it doesn't reach the end of the table it will loop until it has copied the whole table.

