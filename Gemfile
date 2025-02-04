source 'https://rubygems.org' do
  ruby '3.3.5'

  gem 'padrino', '0.16.0.pre3'

  gem 'pg' 

  gem 'activerecord', require: 'active_record'
  gem 'activerecord6-redshift-adapter', git: 'https://github.com/38degrees/activerecord6-redshift-adapter.git', ref: '2aa4069'

  gem 'bcrypt'

  gem 'sidekiq', '~> 7'
  gem 'sidekiq-limit_fetch' 
  gem 'sidekiq-unique-jobs', '~> 8' 

  # TODO: Replace concurrent-ruby commit ref with rubygems version following author release
  #       See Jira issue TTRSUPP-221
  gem 'concurrent-ruby', git: 'https://github.com/ruby-concurrency/concurrent-ruby.git', ref: '56227a4'

  gem 'clockwork'

  gem 'rake'

  gem 'unicorn'

  gem 'aws-sdk-s3', '~> 1'

  gem 'newrelic_rpm'

  gem 'foreman'

  # Error reporting
  gem 'airbrake'
  gem 'sentry-ruby'
  gem 'sentry-sidekiq'

  # Admin
  gem 'will_paginate', git: 'https://github.com/mislav/will_paginate'
  gem 'activerecord_any_of', github: 'oelmekki/activerecord_any_of' # because we're using ActiveRecord
  gem 'activate-admin', git: 'https://github.com/wordsandwriting/activate-admin'
  gem 'activate-tools', git: 'https://github.com/wordsandwriting/activate-tools'

  # Stuff that's being removed from Ruby standard lib in ruby-3.5.0
  # We're just getting ahead of the curve on this one and also it helps silence warnings in the build logs.
  gem 'rexml'
  gem 'ostruct'
  gem 'fiddle'
  gem 'mutex'
  gem 'mutex_m'
  gem 'csv'
end
