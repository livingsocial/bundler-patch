require 'bundler'
require 'bundler/vendor/thor/lib/thor'
require 'bundler/advise'
require 'slop'

module Bundler::Patch
  class CLI
    def self.execute
      opts = Slop.parse! do
        banner "Bundler Patch Version #{Bundler::Patch::VERSION}\nUsage: bundle patch [options] [gems_to_update]\n\nbundler-patch attempts to update gems conservatively.\n"
        on '-m', '--minor-preferred', 'Prefer update to the latest minor.patch version.'
        on '-p', '--prefer-minimal', 'Prefer minimal version updates over most recent patch (or minor if -m used).'
        on '-s', '--strict-updates', 'Restrict any gem to be upgraded past most recent patch (or minor if -m used).'
        on '-l', '--list', 'List vulnerable gems and new version target. No updates will be performed.'
        on '-v', '--vulnerable-gems-only', 'Only update vulnerable gems.'
        on '-a=', '--advisory-db-path=', 'Optional custom advisory db path. `gems` dir will be appended to this path.'
        on '-d=', '--ruby-advisory-db-path=', 'Optional path for ruby advisory db. `gems` dir will be appended to this path.'
        on '-r', '--ruby', 'Update Ruby version in related files.'
        on '--rubies=', 'Supported Ruby versions. Comma delimited or multiple switches.', as: Array, delimiter: ','
        on '-h', 'Show this help'
        on '--help', 'Show README.md'
      end

      options = opts.to_hash
      options[:gems_to_update] = ARGV
      STDERR.puts options.inspect if ENV['DEBUG']

      show_help(opts) if options[:h]
      show_readme if ARGV.include?('help') || options[:help]

      CLI.new.patch(options)
    end

    def self.show_help(opts)
      puts opts
      exit
    end

    def self.show_readme
      Kernel.exec "less '#{File.expand_path('../../../../README.md', __FILE__)}'"
      exit
    end

    def initialize
      @no_vulns_message = 'No known vulnerabilities to update.'
    end

    def patch(options={})
      Bundler.ui = Bundler::UI::Shell.new

      return list(options) if options[:list]

      patch_ruby(options[:rubies]) if options[:ruby]

      patch_gems(options)
    end

    private

    def list(options)
      gem_patches = AdvisoryConsolidator.new(options).vulnerable_gems

      if gem_patches.empty?
        Bundler.ui.info @no_vulns_message
      else
        Bundler.ui.info '' # extra line to separate from advisory db update text
        Bundler.ui.info 'Detected vulnerabilities:'
        Bundler.ui.info '-------------------------'
        Bundler.ui.info gem_patches.map(&:to_s).uniq.sort.join("\n")
      end
    end

    def patch_ruby(supported)
      RubyVersion.new(patched_versions: supported).update
    end

    def patch_gems(options)
      vulnerable_patches = AdvisoryConsolidator.new(options).patch_gemfile_and_get_gem_specs_to_patch
      requested_patches = (options.delete(:gems_to_update) || []).map { |gem_name| GemPatch.new(gem_name: gem_name) }

      all_gem_patches = GemsToPatchReconciler.new(vulnerable_patches, requested_patches).reconciled_patches
      all_gem_patches.push(*vulnerable_patches) if options[:vulnerable_gems_only] && all_gem_patches.empty?

      vulnerable_patches, warnings = vulnerable_patches.partition { |gp| !gp.new_version.nil? }

      unless warnings.empty?
        warnings.each do |gp|
          Bundler.ui.warn "* Could not attempt upgrade for #{gp.gem_name} from #{gp.old_version} to any patched versions " \
            + "#{gp.patched_versions.join(', ')}. Most often this is because a major version increment would be " \
            + "required and it's safer for a major version increase to be done manually."
        end
      end

      if vulnerable_patches.empty?
        Bundler.ui.info @no_vulns_message
      else
        vulnerable_patches.each do |gp|
          Bundler.ui.info "Attempting conservative update for vulnerable gem '#{gp.gem_name}': #{gp.old_version} => #{gp.new_version}"
        end
      end

      if all_gem_patches.empty?
        if options[:vulnerable_gems_only]
          return # nothing to do
        else
          Bundler.ui.info 'Updating all gems conservatively.'
        end
      else
        Bundler.ui.info "Updating '#{all_gem_patches.map(&:gem_name).join(' ')}' conservatively."
      end
      conservative_update(all_gem_patches, options)
    end

    def conservative_update(gem_patches, options={}, bundler_def=nil)
      prep = DefinitionPrep.new(bundler_def, gem_patches, options).tap { |p| p.prep }

      # update => true is very important, otherwise without any Gemfile changes, the installer
      # may end up concluding everything can be resolved locally, nothing is changing,
      # and then nothing is done. lib/bundler/cli/update.rb also hard-codes this.
      Bundler::Installer.install(Bundler.root, prep.bundler_def, {'update' => true})
      Bundler.load.cache if Bundler.app_cache.exist?
    end
  end
end

if __FILE__ == $0
  Bundler::Patch::CLI.execute
end
