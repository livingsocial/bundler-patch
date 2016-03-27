module Bundler::Patch
  module ConservativeDefinition
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
