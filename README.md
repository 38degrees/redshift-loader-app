# Redshift Loader App

Easily deployable to Heroku/Dokku etc. ruby app to incrementally load data from multiple postgres tables into redshift in order to keep a near-realtime replica of your production database for analytics.

It can copy your schema from Postgres to Redshift, perform an initial data load and then keep it up-to-date with changes as long as your tables are either insert-only with a sequential primary key, or have an `updated_at` column with is indexed.


# Getting started

Deploy the app and set environment variables. Run rake db:migrate and rake db:seed to set up the database and an admin user.

Log in to '/admin' with the credentials you just created.

Each pair of postgres database and redshift database is called a 'Job'. Each job has multiple tables which specify tables to be copied, primary_keys, updated_keys and whether the table is insert_only.

Create a new job, then specify a `source_connection_string` and `destination_connection_string`. The `source_connection_string` only needs read-access to the source database. The `destination_connection_string` needs write access to the destination database.

You can run `Job.find(x).setup` to extract all tables in the source database (public schema) and create them in the destination database (public schema). This will attempt to set `primary_key` and `updated_key` for each of the tables, but you will likely need to check and adjust details after you've run 'setup'.

The app uses Clockwork (https://github.com/tomykaira/clockwork) in order to regularly run the import job. In order to set up a regular import job create a new ClockworkEvent with the statement `Job.find(x).run` at your chosen frequency (in seconds).

`.run` is suitable for the intial data load and for incremental loading. It uses the environment variables `IMPORT_ROW_LIMIT` and `IMPORT_CHUNK_SIZE` to determine how much data to copy in one go, but if it doesn't reach the end of the table it will loop until it has copied the whole table.


# Copy modes

This is a new column which is designed to replace `insert_only` (which should become deprecated, and ultimately be deleted)

Available modes:
- `INSERT_ONLY` = only copy new rows, don't update existing rows
- `INSERT_AND_UPDATE` = copy new rows, and update rows which have changed
- `FULL_DATA_SYNC` = full truncate / insert every time the job runs (_Should only be used for overnight jobs, as this will likely mess up ID searches if done while the system is in use!_)


# Scheduling jobs

The `ClockworkEvent` in the database controls the frequency / schedule of a job running. There are two important columns for this,
`frequency` and `at`.

- `frequency` controls how often a job should run, in seconds.
- `at` controls the times at which a job should run - for example, only between 12:00 and 13:00. More information about how `at`
works can be found [here](https://github.com/Rykian/clockwork#at), although the docs are not that useful for what exactly needs
to be inserted into the DB. If you just want a single time, you can just set the column to that value (eg. `'12:**'` for all times
between midday & 1pm). If you want to use multiple times, use a comma separated list, eg `'09:**,10:**,11:**'` will run the job
between 9am and midday.


## Important notes on frequency of jobs!

While the [Clockwork README](https://github.com/Rykian/clockwork) implies that the frequency of jobs running isn't affected by
reloading `ClockworkDatabaseEvent`s, *this is not actually true based on experimentation*!

Our code to reload `ClockworkDatabaseEvent`s lives in `config/clock.rb`, and the frequency of reloading is now controlled by
and ENV VAR, `SYNC_DB_EVENTS_FREQUENCY_MINS`. Previously, this was set to 1, meaning *all jobs would run with a frequency of
at least once a minute, even if this was set higher in the database with the `ClockworkEvent.frequency` column*.

With the ENV VAR alone, jobs would still run at least once every `SYNC_DB_EVENTS_FREQUENCY_MINS` minutes...

A secondary workaround has been put in place, which is implementing the `if?` method on `models/clockwork_event.rb` (our
implementation of a `ClockworkDatabaseEvent`). The `if?` method is checked by clockwork to check if a job should run, and
our implementation double-checks that the difference between the current time and the last time the job succeeded is greater
than or equal to the frequency for the job.


# Temporarily disabling table copies

You can temporarily disable a specific table copy by updating `table.disabled` to `true`. This column should be visible on
ActivateAdmin.


# Creating users in the source and destination databases

It is recommended to use separate, specific users for redshift-loader in your source & destination databases. This means you can limit access to read only the tables you need in the source database, and in both the source & destination databases you can better see which applications are consuming database time & resources.

## Source database

It is recommended you setup a separate, read-only user.

```
# Create user and grant access to database, and access to read the schema
CREATE USER app_redshiftloader_source WITH PASSWORD '<RANDOM_SECURE_PASSWORD>';
GRANT CONNECT ON DATABASE <YOUR_DATABASE_NAME> TO app_redshiftloader_source;
GRANT USAGE ON SCHEMA <YOUR_SCHEMA_NAME> TO app_redshiftloader_source;

# If you want to grant read-only access to specific tables use this:
GRANT SELECT ON <TABLE_1> TO app_redshiftloader_source;
GRANT SELECT ON <TABLE_2> TO app_redshiftloader_source;

# If you want to grant read-only access to ALL tables which currently exist, use this:
GRANT SELECT ON ALL TABLES IN SCHEMA <YOUR_SCHEMA_NAME> TO app_redshiftloader_source;

# If you ALSO want to grant read-only access to any NEW table created in future, use this:
ALTER DEFAULT PRIVILEGES IN SCHEMA <YOUR_SCHEMA_NAME> GRANT SELECT ON TABLES TO app_redshiftloader_source;
```

## Destination database

It is recommended you setup a separate, read-write user - note, this user must also have permissions to create new tables for the `FULL_DATA_SYNC` mode of copying to work, even if copies of all tables already exist in the destination database.

```
# Create user and grant access to database, and access to read the schema and add tables to it
CREATE USER app_redshiftloader_destination WITH PASSWORD '<RANDOM_SECURE_PASSWORD>';
GRANT CONNECT ON DATABASE <YOUR_DATABASE_NAME> TO app_redshiftloader_destination;
GRANT CREATE, USAGE ON SCHEMA <YOUR_SCHEMA_NAME> TO app_redshiftloader_destination;

# Grant read-write permissions to all tables, and all future tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA <YOUR_SCHEMA_NAME> TO app_redshiftloader_destination;
ALTER DEFAULT PRIVILEGES IN SCHEMA <YOUR_SCHEMA_NAME> GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_redshiftloader_destination;
```
