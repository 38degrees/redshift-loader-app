#!/usr/bin/env rackup
# encoding: utf-8

# This file can be used to start Padrino,
# just execute it from the command line.

require 'sidekiq/web'

require File.expand_path("../config/boot.rb", __FILE__)

Sidekiq::Web.use RedshiftLoader::SidekiqAuth

run Rack::URLMap.new(
  '/sidekiq' => Sidekiq::Web,
  '/' => Padrino.application
)
