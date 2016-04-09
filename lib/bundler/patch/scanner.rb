require 'bundler/advise'
require 'boson/runner'

module Bundler::Patch
  class Scanner < Boson::Runner
    def initialize
      @no_vulns_message = 'No known vulnerabilities to update.'
    end

    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    desc 'Scans current directory for known vulnerabilities and outputs them.'

    def scan(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      header
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

    option :strict, type: :boolean, desc: 'Do not allow any gem to be upgraded past most recent release (or minor if -m used). Sometimes raises VersionConflict.'
    option :minor_allowed, type: :boolean, desc: 'Upgrade to the latest minor.release version.'
    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    desc 'Scans current directory for known vulnerabilities and attempts to patch your files to fix them.'

    def patch(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      header

      gems_to_update, warnings = AdvisoryConsolidator.new(options).patch_gemfile_and_get_gem_specs_to_patch

      unless warnings.empty?
        warnings.each do |hash|
          # TODO: Bundler.ui
          puts "* Could not attempt upgrade for #{hash[:gem_name]} from #{hash[:old_version]} to any patched versions " \
            + "#{hash[:patched_versions].join(', ')}. Most often this is because a major version increment would be " \
            + "required and it's safer for a major version increase to be done manually."
        end
      end

      if gems_to_update.empty?
        puts @no_vulns_message
      else
        puts "Updating '#{gems_to_update.map(&:name).join(' ')}' to address vulnerabilities"
        conservative_update(gems_to_update, options.merge(patching: true))
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
      gems_to_update = options[:gems_to_update] || true
      conservative_update(gems_to_update, options)
    end

    private

    def header
      puts "Bundler Patch Version #{Bundler::Patch::VERSION}"
    end

    def conservative_update(gems_to_update, options={}, bundler_def=nil)
      Bundler.ui = Bundler::UI::Shell.new

      prep = DefinitionPrep.new(bundler_def, gems_to_update, options).tap { |p| p.prep }

      # TODO: review where the update key's value is used? Can't find it.
      options = {'update' => prep.unlock}
      Bundler::Installer.install(Bundler.root, prep.bundler_def, options)
    end
  end
end
