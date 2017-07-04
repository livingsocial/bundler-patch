require 'bundler'
require 'bundler/vendor/thor/lib/thor'
require 'bundler/advise'
require 'slop'

module Bundler::Patch
  class CLI
    def self.execute
      original_command = ARGV.join(' ')

      opts = Slop.parse! do
        banner "Bundler Patch Version #{Bundler::Patch::VERSION}\nUsage: bundle patch [options] [gems-to-update]\n\nbundler-patch attempts to update gems conservatively.\n"
        on '-m', '--minor', 'Prefer update to the latest minor.patch version.'
        on '-n', '--minimal', 'Prefer minimal version updates over most recent patch (or minor if -m used).'
        on '-s', '--strict', 'Restrict any gem to be upgraded past most recent patch (or minor if -m used).'
        on '-l', '--list', 'List vulnerable gems and new version target. No updates will be performed.'
        on '-v', '--vulnerable-gems-only', 'Only update vulnerable gems.'
        on '-a=', '--advisory-db-path=', 'Optional custom advisory db path. `gems` dir will be appended to this path.'
        on '-d=', '--ruby-advisory-db-path=', 'Optional path for ruby advisory db. `gems` dir will be appended to this path.'
        on '-r', '--ruby', 'Update Ruby version in related files.'
        on '--rubies=', 'Supported Ruby versions. Comma delimited or multiple switches.', as: Array, delimiter: ','
        on '-g=', '--gemfile=', 'Optional Gemfile to execute against. Defaults to Gemfile in current directory.'
        on '--use_target_ruby', 'Optionally attempt to use Ruby version of target bundle specified in --gemfile.'
        on '-h', 'Show this help'
        on '--help', 'Show README.md'

        # will be stripped in help display and normalized to hyphenated options
        on '--vulnerable_gems_only'
        on '--advisory_db_path='
        on '--ruby_advisory_db_path='
        on '-p', '--prefer_minimal'
        on '--minor_preferred'
        on '--strict_updates'
      end

      options = opts.to_hash
      options[:gems_to_update] = ARGV
      options[:original_command] = original_command
      STDERR.puts options.inspect if ENV['DEBUG']

      show_help(opts) if options[:h]
      show_readme if ARGV.include?('help') || options[:help]

      CLI.new.patch(options)
    end

    def self.show_help(slop)
      slop.options.delete_if { |o| o.long =~ /_/ }
      puts slop
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

      normalize_options(options)

      process_gemfile_option(options)

      if options[:use_target_ruby] # TODO: && different_ruby_found
        tb = options[:target]
        ruby = tb.ruby_bin_exe
        tb.install_bundler_patch_in_target
        bundler_patch = File.join(tb.ruby_bin, 'bundler-patch') # uses 'latest' bundler-patch, which can work after we've installed ours. 
        full_command = "#{ruby} #{bundler_patch} #{options[:original_command].gsub(/use_target_ruby/, '')}"
        puts full_command #if $DEBUG
        puts `#{full_command}`
      else
        return list(options) if options[:list]

        patch_ruby(options) if options[:ruby]

        patch_gems(options)
      end
    end

    def normalize_options(options)
      map = {:prefer_minimal => :minimal, :strict_updates => :strict, :minor_preferred => :minor}
      {}.tap do |target|
        options.each_pair do |k, v|
          new_key = k.to_s.gsub('-', '_').to_sym
          new_key = map[new_key] || new_key
          target[new_key] = v
        end
      end
    end

    private

    def process_gemfile_option(options)
      # copy/pasta from Bundler
      custom_gemfile = options[:gemfile] || Bundler.settings[:gemfile]
      if custom_gemfile && !custom_gemfile.empty?
        ENV['BUNDLE_GEMFILE'] = File.expand_path(custom_gemfile)
        dir, gemfile = [File.dirname(custom_gemfile), File.basename(custom_gemfile)]
        target_bundle = TargetBundle.new(dir: dir, gemfile: gemfile)
        options[:target] = target_bundle
      else
        options[:target] = TargetBundle.new
      end
    end

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

    def patch_ruby(options)
      supported = options[:rubies]
      RubyVersion.new(target_bundle: options[:target], patched_versions: supported).update
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
      Bundler::Installer.install(options[:target].dir, prep.bundler_def, {'update' => true})
      Bundler.load.cache if Bundler.app_cache.exist?
    end
  end
end

if __FILE__ == $0
  Bundler::Patch::CLI.execute
end
