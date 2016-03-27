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
      _scan(options)

      if @specs.empty?
        puts @no_vulns_message
      else
        puts # extra line to separate from advisory db update text
        puts 'Detected vulnerabilities:'
        puts '-------------------------'
        puts @specs.map(&:to_s).uniq.sort.join("\n")
      end
    end

    option :strict, type: :boolean, desc: 'Do not allow any gem to be upgraded past most recent release (or minor if -m used). Sometimes raises VersionConflict.'
    option :minor_allowed, type: :boolean, desc: 'Upgrade to the latest minor.release version.'
    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    desc 'Scans current directory for known vulnerabilities and attempts to patch your files to fix them.'

    def patch(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      _scan(options)

      @specs.map(&:update)
      gems = @specs.map(&:gem_name)
      if gems.empty?
        puts @no_vulns_message
      else
        gems_to_update = gems.uniq
        puts "Updating '#{gems_to_update.join(' ')}' to address vulnerabilities"
        conservative_update(gems_to_update, options)
      end
    end

    option :strict, type: :boolean, desc: 'Do not allow any gem to be upgraded past most recent release (or minor if -m used). Sometimes raises VersionConflict.'
    option :minor_allowed, type: :boolean, desc: 'Upgrade to the latest minor.release version.'
    # TODO: be nice to support array w/o quotes like real `bundle update`
    option :gems_to_update, type: :array, split: ' ', desc: 'Optional list of gems to update, in quotes, space delimited'
    desc 'Update spec gems to the latest release version. Required gems could be upgraded to latest minor or major if necessary.'
    config default_option: 'gems_to_update'

    def update(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      gems_to_update = options[:gems_to_update] || true
      conservative_update(gems_to_update, options)
    end

    private

    def conservative_update(gems_to_update, options={}, bundler_def=nil)
      Bundler.ui = Bundler::UI::Shell.new

      prep = DefinitionPrep.new(bundler_def, gems_to_update, options).tap { |p| p.prep }

      options = {'update' => prep.unlock}
      Bundler::Installer.install(Bundler.root, prep.bundler_def, options)
    end

    def _scan(options)
      @specs = AdvisoryConsolidator.new(options).vulnerable_gems
    end
  end
end

module Bundler::Patch
  class DefinitionPrep
    attr_reader :unlock, :bundler_def

    def initialize(bundler_def, gems_to_update, options)
      @bundler_def = bundler_def
      @gems_to_update = gems_to_update
      @options = options
    end

    def prep
      gems_to_update = Array(@gems_to_update)

      @unlock = (gems_to_update === [true]) ? true : {gems: gems_to_update}
      @bundler_def ||= Bundler.definition(unlock)
      @bundler_def.extend ConservativeDefinition
      @bundler_def.gems_to_update = gems_to_update
      @bundler_def.strict = @options[:strict]
      @bundler_def.minor_allowed = @options[:minor_allowed]
      @bundler_def
    end
  end
end

module Bundler::Patch
  module ConservativeDefinition
    # @unlock holds these in the initializer, but it gets eager_loaded
    # by the end of it, and won't serve the purpose this module needs.
    attr_accessor :gems_to_update

    # pass-through options to ConservativeResolver
    attr_accessor :strict, :minor_allowed

    # This copies way too much code, but for now is an acceptable step forward. Intervening into the creation
    # of a Definition instance is a bit of a pain, a lot of preliminary data has to be gathered first, and
    # copying this one method, avoids copying much of that code. Pick your poison.
    def resolve
      @resolve ||= begin
        last_resolve = converge_locked_specs
        if Bundler.settings[:frozen] || (!@unlocking && nothing_changed?)
          last_resolve
        else
          # Run a resolve against the locally available gems
          base = last_resolve.is_a?(Bundler::SpecSet) ? Bundler::SpecSet.new(last_resolve) : []
          resolver = ConservativeResolver.new(index, source_requirements, base)
          locked_specs = if @unlocking && @locked_specs.length == 0
                           # Have to grab these again. Default behavior is to not store any
                           # locked_specs if updating all gems, because behavior is the same
                           # with no lockfile OR lockfile but update them all. In our case,
                           # we need to know the locked versions for conservative comparison.
                           locked = Bundler::LockfileParser.new(@lockfile_contents)
                           resolver.unlocking_all = true
                           Bundler::SpecSet.new(locked.specs)
                         else
                           resolver.unlocking_all = false
                           @locked_specs
                         end
          resolver.locked_specs = locked_specs
          resolver.unlock = @gems_to_update
          resolver.strict = @strict
          resolver.minor_allowed = @minor_allowed
          result = resolver.start(expanded_dependencies)
          spec_set = Bundler::SpecSet.new(result)

          last_resolve.merge spec_set
        end
      end
    end
  end
end
