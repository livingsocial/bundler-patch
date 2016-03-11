$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

require 'bundler/patch'

include Bundler::Patch

require 'bundler/fixture'
