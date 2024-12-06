source 'https://rubygems.org' do
  ruby '3.3.5'

  gem 'padrino', '0.16.0.pre3'

  gem 'pg', 

  gem 'activerecord', require: 'active_record'
  gem 'activerecord4-redshift-adapter'

  gem 'bcrypt'

  gem 'sidekiq', '~> 7'
  gem 'sidekiq-limit_fetch', 
  gem 'sidekiq-unique-jobs', '~> 8' 

  # TODO: Replace concurrent-ruby commit ref with rubygems version following author release
  #       See Jira issue TTRSUPP-221
  gem 'concurrent-ruby', git: 'https://github.com/ruby-concurrency/concurrent-ruby.git', ref: '56227a4'

  gem 'clockwork'

  gem 'rake'

  gem 'unicorn'

  # Why are we not using the official AWS SDK here 🤨
  gem 's3', '0.3.29' # un-Fixes private method delegation errors

  gem 'newrelic_rpm'

  gem 'foreman'

  # Error reporting
  gem 'airbrake'
  gem 'sentry-ruby'
  gem 'sentry-sidekiq'

  # Admin
  gem 'will_paginate', git: 'https://github.com/mislav/will_paginate'

  gem 'activate-admin', git: 'https://github.com/wordsandwriting/activate-admin'
  gem 'activate-tools', git: 'https://github.com/wordsandwriting/activate-tools'
end
