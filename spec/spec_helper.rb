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

class BundlerFixture
  def gemfile_contents
    File.read(gemfile_filename)
  end

  def lockfile_spec_version(gem_name)
    parsed_lockfile_spec(gem_name).version.to_s
  end
end

def with_clean_env
  Bundler.with_clean_env do
    ENV['GEM_PATH'] = nil if ENV['GEM_PATH'] == '' # bug fix for clean_env?
    yield
  end
end

def bundler_patch(options)
  cmd = File.expand_path('../bin/bundler-patch', __dir__)
  opts = options.map do |k, v|
    if k == :gems_to_update
      v.join(' ')
    else
      "--#{k} #{v}"
    end
  end.join(' ')
  puts `#{cmd} #{opts}`
end
