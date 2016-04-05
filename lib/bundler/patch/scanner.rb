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
      _scan(options)

      if @gem_patches.empty?
        puts @no_vulns_message
      else
        puts # extra line to separate from advisory db update text
        puts 'Detected vulnerabilities:'
        puts '-------------------------'
        puts @gem_patches.map(&:to_s).uniq.sort.join("\n")
      end
    end

    option :strict, type: :boolean, desc: 'Do not allow any gem to be upgraded past most recent release (or minor if -m used). Sometimes raises VersionConflict.'
    option :minor_allowed, type: :boolean, desc: 'Upgrade to the latest minor.release version.'
    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    desc 'Scans current directory for known vulnerabilities and attempts to patch your files to fix them.'

    def patch(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      header
      _scan(options)

      @gem_patches.map(&:update)
      locked = Bundler::LockfileParser.new(Bundler.read_file(Bundler.default_lockfile)).specs

      gems_to_update = @gem_patches.map do |p|
        old_version = locked.detect { |s| s.name == p.gem_name }.version.to_s
        new_version = p.calc_new_version(old_version)
        p "Attempting #{p.gem_name}: #{old_version} => #{new_version}" if ENV['DEBUG_PATCH_RESOLVER']
        Gem::Specification.new(p.gem_name, new_version)
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

    def _scan(options)
      @gem_patches = AdvisoryConsolidator.new(options).vulnerable_gems
    end
  end
end
