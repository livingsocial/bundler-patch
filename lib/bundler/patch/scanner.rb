require 'bundler/advise'
require 'boson/runner'

module Bundler::Patch
  class Scanner < Boson::Runner
    def initialize
      @no_vulns_message = 'No known vulnerabilities to update.'
    end

    # strict could- if not unlocking gem, restrict available to just the locked version.
    #             - patching, encourage minimum patch even if a later release (or minor) exists
    # IOW - patching as a flag goes away. strict is what signals 'patching' behavior.

    option :list, type: :boolean, desc: 'List vulnerabilities. No updates will be performed.'
    option :strict, type: :boolean, desc: 'Do not allow any gem to be upgraded past most recent release (or minor if -m used). Sometimes raises VersionConflict.'
    option :minor_allowed, type: :boolean, desc: 'Upgrade to the latest minor.release version.'
    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    option :vulnerable_gems_only, type: :boolean, alias: '-i', desc: 'Only update vulnerable gems.'
    # TODO: be nice to support array w/o quotes like real `bundle update`
    option :gems_to_update, type: :array, split: ' ', desc: 'Optional list of gems to update, in quotes, space delimited'
    # desc 'Scans current directory for known vulnerabilities and attempts to patch your files to fix them.'
    config default_option: 'gems_to_update'

    def patch(options={})
      header

      return list(options) if options[:list]

      _patch(options)
    end

    private

    def header
      puts "Bundler Patch Version #{Bundler::Patch::VERSION}"
    end

    def conservative_update(gem_patches, options={}, bundler_def=nil)
      Bundler.ui = Bundler::UI::Shell.new

      prep = DefinitionPrep.new(bundler_def, gem_patches, options).tap { |p| p.prep }

      Bundler::Installer.install(Bundler.root, prep.bundler_def)
    end

    def list(options)
      gem_patches = AdvisoryConsolidator.new(options).vulnerable_gems

      if gem_patches.empty?
        puts @no_vulns_message
      else
        puts # extra line to separate from advisory db update text
        puts 'Detected vulnerabilities:'
        puts '-------------------------'
        puts gem_patches.map(&:to_s).uniq.sort.join("\n")
      end
    end

    def _patch(options)
      vuln_gem_patches, warnings = AdvisoryConsolidator.new(options).patch_gemfile_and_get_gem_specs_to_patch

      requested_gem_patches = (options.delete(:gems_to_update) || []).map { |gem_name| GemPatch.new(gem_name: gem_name) }

      all_gem_patches = []
      unless requested_gem_patches.empty?
        requested_gem_names = requested_gem_patches.map(&:gem_name)
        # TODO: this would be simpler with set operators given proper <=> on GemPatch, right?
        vuln_gem_patches.reject! { |gp| !requested_gem_names.include?(gp.gem_name) }
        warnings.reject! { |gp| !requested_gem_names.include?(gp.gem_name) }

        all_gem_patches.push(*vuln_gem_patches)

        gem_patches_names = all_gem_patches.map(&:gem_name)
        requested_gem_patches.each { |gp| all_gem_patches << gp unless gem_patches_names.include?(gp.gem_name) }
      end

      unless warnings.empty?
        warnings.each do |gp|
          # TODO: Bundler.ui
          puts "* Could not attempt upgrade for #{gp.gem_name} from #{gp.old_version} to any patched versions " \
            + "#{gp.patched_versions.join(', ')}. Most often this is because a major version increment would be " \
            + "required and it's safer for a major version increase to be done manually."
        end
      end

      if vuln_gem_patches.empty?
        puts @no_vulns_message
      else
        vuln_gem_patches.each do |gp|
          puts "Attempting update for vulnerable gem '#{gp.gem_name}': #{gp.old_version} => #{gp.new_version}" # TODO: Bundler.ui
        end
      end

      if all_gem_patches.empty?
        puts 'Updating all gems conservatively.'
      else
        puts "Updating '#{all_gem_patches.map(&:gem_name).join(' ')}'"
      end
      conservative_update(all_gem_patches, options.merge(patching: !vuln_gem_patches.empty?))
      #conservative_update(all_gem_patches, options.merge(patching: false))
    end
  end
end
