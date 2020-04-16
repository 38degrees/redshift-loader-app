#!/bin/bash
#
# Steps 1-3 & 5 install rbenv, ruby and Postgres following instructions as per go rails:
# https://gorails.com/setup/ubuntu/14.04
# (altered so that everything runs in a shell script)
#
# Step 4 installs Padrino (instead of rails)
# 
# Step 6 installs redis-server 3.x from a non-standard ubuntu repo, because ubuntu
# official repos only have 2.x
# 
# Once you've setup the vagrant box with vagrant up and SSH'd on with vagrant SSH
# you should setup the DB by running sudo su - postgres and then running psql and
# finally following the instructions on setting up the DB in the readshift-loader
# README
# 
# A full set of commands to get you up and running *should* be:
# 
# vagrant up
# vagrant ssh
# 
# sudo su - postgres
# psql
# 
# CREATE DATABASE loader_dev encoding=UTF8;
# CREATE ROLE loader WITH SUPERUSER LOGIN ENCRYPTED PASSWORD 'mypassword';
# \connect loader_dev
# CREATE SCHEMA loader AUTHORIZATION loader;
# \q
# 
# exit
# 
# cd /vagrant
# bundle install
#
# (you will need an appropriate .env file, which is likely to vary by organisation...)
# (if you want to run padrino console, you'll also need to copy your .env file to .env.development)
#
# foreman run rake ar:schema:load
# foreman run rake db:seed
#
# foreman start -f Procfile


su vagrant << EOF
    
    echo "*** STEP 0 - Ensuring we're using UTF8 encoding ***"
    sudo locale-gen en_US.UTF-8
    sudo update-locale  LANG=en_us.UTF-8 LANGUAGE="" LC_CTYPE="en_US.UTF-8" \
                        LC_NUMERIC="en_US.UTF-8" LC_TIME="en_US.UTF-8" \
                        LC_COLLATE="en_US.UTF-8" LC_MONETARY="en_US.UTF-8" \
                        LC_MESSAGES="en_US.UTF-8" LC_PAPER="en_US.UTF-8" \
                        LC_NAME="en_US.UTF-8" LC_ADDRESS="en_US.UTF-8" \
                        LC_TELEPHONE="en_US.UTF-8" LC_MEASUREMENT="en_US.UTF-8" \
                        LC_IDENTIFICATION="en_US.UTF-8" LC_ALL=en_US.UTF-8
    
    echo "*** STEP 1 - Installing core dependencies using apt-get ***"
    sudo apt-get update
    sudo apt-get install -y  git  git-core  curl  zlib1g-dev  build-essential  libssl-dev  \
                             libreadline-dev  libyaml-dev  libsqlite3-dev  sqlite3  libxml2-dev  \
                             libxslt1-dev  libcurl4-openssl-dev  python-software-properties  \
                             libffi-dev  nodejs  libmysqlclient-dev  cmake


    echo "*** STEP 2 - Downloading rbenv from github, and adding it to PATH ***"
    cd
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="\$HOME/.rbenv/bin:\$PATH"' >> ~/.bashrc
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    echo 'export PATH="\$HOME/.rbenv/plugins/ruby-build/bin:\$PATH"' >> ~/.bashrc
    echo 'eval "\$(rbenv init -)"' >> ~/.bashrc
    PS1='$ '  # Trick .bashrc into thinking we're running interactively, which allows us to 'source ~/.bashrc'
    source ~/.bashrc


    echo "*** STEP 3 - Installing ruby 2.2.6 using rbenv ***"
    rbenv install 2.6.0
    rbenv global 2.6.0

    gem install bundler
    rbenv rehash


    echo "*** STEP 4 - Install Padrino & Foreman using gem install ***"
    gem install padrino
    gem install foreman
    rbenv rehash


    echo "*** STEP 5 - Installing postgresql using apt-get ***"
    sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
    wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install -y  postgresql-common  postgresql-9.5  libpq-dev
    sudo apt-get install -y  postgresql-plpython-9.5
    
    
    # echo "*** STEP 6 - Installing redis using apt-get ***"
    # sudo add-apt-repository -y ppa:chris-lea/redis-server
    # sudo apt-get update
    # sudo apt-get install -y redis-server=3:3.0.7-1chl1~precise1

EOF
