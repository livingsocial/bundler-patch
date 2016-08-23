$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

require 'bundler/patch'

include Bundler::Patch

require 'bundler/fixture'
require_relative './fixture/gemfile_fixture'

def bundler_1_13?
  Gem::Version.new(Bundler::VERSION) >= Gem::Version.new('1.13.0.rc.2')
end
