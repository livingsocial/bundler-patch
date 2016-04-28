require 'bundler'

module Bundler
  module Patch
  end
end

require 'bundler/patch/updater'
require 'bundler/patch/gemfile'
require 'bundler/patch/ruby_version'
require 'bundler/patch/advisory_consolidator'
require 'bundler/patch/conservative_definition'
require 'bundler/patch/conservative_resolver'
require 'bundler/patch/gems_to_patch_reconciler'
require 'bundler/patch/cli'
require 'bundler/patch/version'
