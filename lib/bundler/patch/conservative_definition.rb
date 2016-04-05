module Bundler::Patch
  module ConservativeDefinition
    attr_accessor :gems_to_update

    # pass-through options to ConservativeResolver
    attr_accessor :strict, :minor_allowed, :patching

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

          @gems_to_update.fixup_locked_specs(locked_specs)
          resolver.unlock = @gems_to_update.to_gem_names
          resolver.locked_specs = locked_specs
          resolver.strict = @strict
          resolver.minor_allowed = @minor_allowed
          resolver.patching = @patching
          result = resolver.start(expanded_dependencies)
          spec_set = Bundler::SpecSet.new(result)

          last_resolve.merge spec_set
        end
      end
    end
  end

  class DefinitionPrep
    attr_reader :unlock, :bundler_def

    def initialize(bundler_def, gems_to_update, options)
      @bundler_def = bundler_def
      @gems_to_update = GemsToUpdate.new(gems_to_update, options[:patching])
      @options = options
    end

    def prep
      @unlock = @gems_to_update.to_bundler_install_options
      @bundler_def ||= Bundler.definition(@gems_to_update.to_bundler_definition)
      @bundler_def.extend ConservativeDefinition
      @bundler_def.gems_to_update = @gems_to_update
      @bundler_def.strict = @options[:strict]
      @bundler_def.minor_allowed = @options[:minor_allowed]
      @bundler_def.patching = @options[:patching]
      @bundler_def
    end
  end

  class GemsToUpdate
    # @param `true`, [String] or [Gem::Dependency] gems_to_update
    # @param [boolean] patching. Patching is special, we need to communicate 'true'
    #                            into the innards of Bundler, but keep a list of
    #                            gems we're patching handy for our Resolver. (TODO: or do we?)
    def initialize(gems_to_update, patching)
      @gems_to_update = Array(gems_to_update)
      @patching = patching
    end

    def to_bundler_install_options
      # This may not be correct for bundler install
      {gems: (gem_names_should_or_does_equal_true? ? true : to_gem_names)}
    end

    def to_bundler_definition
      gem_names_should_or_does_equal_true? ? true : {gems: to_gem_names}
    end

    def gem_names_should_or_does_equal_true?
      @patching || (to_gem_names === true)
    end

    def to_gem_names
      if @gems_to_update === [true]
        true
      elsif @gems_to_update.first.respond_to?(:name)
        @gems_to_update.map(&:name)
      else
        @gems_to_update
      end
    end

    def fixup_locked_specs(locked_specs)
      @gems_to_update.each do |up_spec|
        next unless up_spec.respond_to?(:name)
        to_fix = locked_specs[up_spec.name]
        to_fix.first.instance_variable_set('@version', up_spec.version)
      end
    end
  end
end
