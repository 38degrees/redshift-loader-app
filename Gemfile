source 'https://rubygems.org' do
  ruby '2.5.9'

  gem 'padrino'

  gem 'pg', '~> 0.21' # Can't be higher with Ruby 2.3.8

  gem 'activerecord', require: 'active_record'
  gem 'activerecord4-redshift-adapter'

  gem 'bcrypt'

  gem 'sidekiq'
  gem 'sidekiq-limit_fetch'
  gem 'sidekiq-unique-jobs', '~> 5.0.11' # Can't be higher with 2.3.8

  gem 'clockwork'

  gem 'rake'

  gem 'unicorn'

  gem 's3', '0.3.29' # un-Fixes private method delegation errors

  gem 'newrelic_rpm'

  gem 'foreman'

  gem 'airbrake'
  gem 'rubocop'

  # Admin
  gem 'will_paginate', git: 'https://github.com/mislav/will_paginate'

  gem 'activate-admin', git: 'https://github.com/wordsandwriting/activate-admin'
  gem 'activate-tools', git: 'https://github.com/wordsandwriting/activate-tools'
end
