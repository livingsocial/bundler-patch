$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

require 'bundler/patch'

include Bundler::Patch

require 'fixture/bundler_fixture'

#gem_root_path = Gem.loaded_specs['bundler-advise'].full_gem_path
#require File.join(gem_root_path, 'spec', 'fixture', 'bundler_fixture')

