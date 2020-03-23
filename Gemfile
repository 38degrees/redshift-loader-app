source 'https://rubygems.org'

ruby '2.2.8'

# Project requirements
gem 'rake'
gem 'unicorn'
gem 's3', '~> 0.3.29' # Fixes private method delegation errors on Ruby 2.5+
gem 'clockwork', '~> 2.0' #clock process
gem 'sidekiq', '~> 5.0.4'
gem 'sidekiq-limit_fetch'
gem 'sidekiq-unique-jobs', '~> 5.0.10'
gem 'newrelic_rpm' #app monitoring
gem 'foreman'

# Admin
gem 'will_paginate', git: 'https://github.com/mislav/will_paginate'
gem 'activate-admin', git: 'https://github.com/wordsandwriting/activate-admin'
gem 'activate-tools', git: 'https://github.com/wordsandwriting/activate-tools'

# Component requirements
gem 'bcrypt'
gem 'activerecord', '>= 4.1.14.1', :require => 'active_record'
gem 'pg'
gem 'activerecord4-redshift-adapter'

# Test requirements

# Padrino Stable Gem
gem 'padrino', '0.13.2'
