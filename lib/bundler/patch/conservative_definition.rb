module Bundler::Patch
  module ConservativeDefinition
    attr_accessor :gems_to_update

    # pass-through options to ConservativeResolver
    attr_accessor :strict, :minor_allowed

    # This copies more code than I'd like out of Bundler::Definition, but for now seems the least invasive way in.
    # Backing up and intervening into the creation of a Definition instance itself involves a lot more code, a lot
    # more preliminary data has to be gathered first.
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
                           Bundler::SpecSet.new(locked.specs)
                         else
                           @locked_specs
                         end

          resolver.gems_to_update = @gems_to_update
          resolver.locked_specs = locked_specs
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
    attr_reader :bundler_def

    def initialize(bundler_def, gem_patches, options)
      @bundler_def = bundler_def
      @gems_to_update = GemsToUpdate.new(gem_patches, options)
      @options = options
    end

    def prep
      @bundler_def ||= Bundler.definition(@gems_to_update.to_bundler_definition)
      @bundler_def.extend ConservativeDefinition
      @bundler_def.gems_to_update = @gems_to_update
      @bundler_def.strict = @options[:strict]
      @bundler_def.minor_allowed = @options[:minor_allowed]
      fixup_empty_remotes if @gems_to_update.to_bundler_definition === true
      @bundler_def
    end

    # This may only matter in cases like sidekiq where the sidekiq-pro gem is served
    # from their gem server and depends on the open-source sidekiq gem served from
    # rubygems.org, and when patching those, without the appropriate remotes being
    # set in rubygems_aggregrate, it won't work.
    #
    # I've seen some other weird cases where a remote source index had no entry for a
    # gem and would trip up bundler-audit. I couldn't pin them down at the time though.
    # But I want to keep this in case.
    #
    # The underlying issue in Bundler 1.10 appears to be when the Definition
    # constructor receives `true` as the `unlock` parameter, then @locked_sources
    # is initialized to empty array, and the related rubygems_aggregrate
    # source instance ends up with no @remotes set in it, which I think happens during
    # converge_sources. Without those set, then the index will list no gem versions in
    # some cases. (It was complicated enough to discover this patch, I haven't fully
    # worked out the flaw, which still could be on my side of the fence).
    def fixup_empty_remotes
      b_sources = @bundler_def.send(:sources)
      empty_remotes = b_sources.rubygems_sources.detect { |s| s.remotes.empty? }
      empty_remotes.remotes.push(*b_sources.rubygems_remotes) if empty_remotes
    end
  end

  class GemsToUpdate
    attr_reader :gem_patches, :patching

    def initialize(gem_patches, options={})
      @gem_patches = Array(gem_patches)
      @patching = options[:patching]
    end

    def to_bundler_definition
      unlocking_all? ? true : {gems: to_gem_names}
    end

    def to_gem_names
      @gem_patches.map(&:gem_name)
    end

    def patching_gem?(gem_name)
      @patching && to_gem_names.include?(gem_name)
    end

    def patching_but_not_this_gem?(gem_name)
      @patching && !to_gem_names.include?(gem_name)
    end

    def gem_patch_for(gem_name)
      @gem_patches.detect { |gp| gp.gem_name == gem_name }
    end

    def unlocking_all?
      @patching || @gem_patches.empty?
    end

    def unlocking_gem?(gem_name)
      unlocking_all? || to_gem_names.include?(gem_name)
    end
  end
end
