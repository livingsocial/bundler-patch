require 'bundler/advise'
require 'boson/runner'

module Bundler::Patch
  class Scanner < Boson::Runner
    def initialize
      @no_vulns_message = 'No known vulnerabilities to update.'
    end

    option :list, type: :boolean, desc: 'List vulnerabilities. No updates will be performed.'
    option :strict, type: :boolean, desc: 'Do not allow any gem to be upgraded past most recent release (or minor if -m used). Sometimes raises VersionConflict.'
    option :minor_allowed, type: :boolean, desc: 'Upgrade to the latest minor.release version.'
    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    desc 'Scans current directory for known vulnerabilities and attempts to patch your files to fix them.'

    def patch(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      header

      return list(options) if options[:list]

      gem_patches, warnings = AdvisoryConsolidator.new(options).patch_gemfile_and_get_gem_specs_to_patch

      unless warnings.empty?
        warnings.each do |gp|
          # TODO: Bundler.ui
          puts "* Could not attempt upgrade for #{gp.gem_name} from #{gp.old_version} to any patched versions " \
            + "#{gp.patched_versions.join(', ')}. Most often this is because a major version increment would be " \
            + "required and it's safer for a major version increase to be done manually."
        end
      end

      if gem_patches.empty?
        puts @no_vulns_message
      else
        gem_patches.each do |gp|
          puts "Attempting #{gp.gem_name}: #{gp.old_version} => #{gp.new_version}" # TODO: Bundler.ui
        end

        puts "Updating '#{gem_patches.map(&:gem_name).join(' ')}' to address vulnerabilities"
        conservative_update(gem_patches, options.merge(patching: true))
      end
    end

    option :strict, type: :boolean, desc: 'Do not allow any gem to be upgraded past most recent release (or minor if -m used). Sometimes raises VersionConflict.'
    option :minor_allowed, type: :boolean, desc: 'Upgrade to the latest minor.release version.'
    # TODO: be nice to support array w/o quotes like real `bundle update`
    option :gems_to_update, type: :array, split: ' ', desc: 'Optional list of gems to update, in quotes, space delimited'
    desc 'Update spec gems to the latest release version. Required gems could be upgraded to latest minor or major if necessary.'
    config default_option: 'gems_to_update'

    def update(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      header
      gem_patches = (options.delete(:gems_to_update) || []).map { |gem_name| GemPatch.new(gem_name: gem_name) }
      conservative_update(gem_patches, options.merge(updating: true))
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
  end
end
