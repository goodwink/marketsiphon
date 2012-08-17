#!/usr/bin/env ruby

($: << ['./app', './config']).flatten!

require 'rubygems'
require 'bundler/setup'

ENV['RACK_ENV'] ||= 'development'
Bundler.require :default, ENV['RACK_ENV']

require 'market_siphon'

if ENV['RACK_ENV'] == 'development' || ENV['RACK_ENV'] == 'test'
  use Rack::Reloader, 1
end

map '/assets' do
  environment = Sprockets::Environment.new do |env|
    env.logger = Logger.new(STDOUT)
  end

  bootstrap_path =  Gem.loaded_specs['bootstrap-sass'].full_gem_path

  environment.append_path 'assets/stylesheets'
  environment.append_path 'assets/javascripts'
  environment.append_path 'vendor/assets/javascripts'
  environment.append_path 'vendor/assets/stylesheets'
  environment.append_path "#{bootstrap_path}/vendor/assets/javascripts"
  environment.append_path "#{bootstrap_path}/vendor/assets/stylesheets"
  environment.append_path 'spec/javascripts'
  environment.append_path 'assets/images'

  Sprockets::Helpers.configure do |config|
    config.environment = environment
    config.prefix      = '/assets'
    config.digest      = false
  end

  run environment
end

map '/api' do
  run MarketSiphon::API.new
end

use Rack::Static, urls: [''], root: 'public', index: 'index.html'

run ->(env){[200, {'Content-Type' => 'text/html'}, [File.read(File.join('public', 'index.html'))]]}
