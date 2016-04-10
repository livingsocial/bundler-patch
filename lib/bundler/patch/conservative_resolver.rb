module Bundler::Patch
  class ConservativeResolver < Bundler::Resolver
    attr_accessor :locked_specs, :gems_to_update, :strict, :minor_allowed

    def search_for(dependency)
      res = super(dependency)

      dep = dependency.dep unless dependency.is_a? Gem::Dependency
      @conservative_search_for ||= {}
      #@conservative_search_for[dep] ||= # TODO turning off caching allowed a real-world sample to work, dunno why yet.
      begin
        gem_name = dep.name
        unlocking_gem = @gems_to_update.unlocking_gem?(gem_name)

        # An Array per version returned, different entries for different platforms.
        # We just need the version here so it's ok to hard code this to the first instance.
        locked_spec = @locked_specs[gem_name].first

        (@strict ?
          filter_specs(res, unlocking_gem, locked_spec) :
          sort_specs(res, unlocking_gem, locked_spec)).tap do |res|
          if ENV['DEBUG_PATCH_RESOLVER']
            # TODO: if we keep this, gotta go through Bundler.ui
            begin
              if res
                p debug_format_result(dep, res)
              else
                p "No res for #{dep.to_s}. Orig res: #{super(dependency)}"
              end
            rescue => e
              p [e.message, e.backtrace[0..5]]
            end
          end
        end
      end
    end

    def debug_format_result(dep, res)
      a = [dep.to_s,
           res.map { |sg| [sg.version, sg.dependencies_for_activated_platforms.map { |dp| [dp.name, dp.requirement.to_s] }] }]
      [a.first, a.last.map { |sg_data| [sg_data.first.version, sg_data.last.map { |aa| aa.join(' ') }] }]
    end

    def filter_specs(specs, unlocking_gem, locked_spec)
      res = specs.select do |sg|
        # SpecGroup is grouped by name/version, multiple entries for multiple platforms.
        # We only need the name, which will be the same, so hard coding to first is ok.
        gem_spec = sg.first

        if locked_spec
          gsv = gem_spec.version
          lsv = locked_spec.version

          must_match = @minor_allowed ? [0] : [0, 1]

          matches = must_match.map { |idx| gsv.segments[idx] == lsv.segments[idx] }
          (matches.uniq == [true]) ? gsv.send(:>=, lsv) : false
        else
          true
        end
      end

      sort_specs(res, unlocking_gem, locked_spec)
    end

    def sort_specs(specs, unlocking_gem, locked_spec)
      return specs unless locked_spec
      gem_name = locked_spec.name
      locked_version = locked_spec.version

      filtered = specs.select { |s| s.first.version >= locked_version }

      filtered.sort do |a, b|
        a_ver = a.first.version
        b_ver = b.first.version
        case
        when a_ver.segments[0] != b_ver.segments[0]
          b_ver <=> a_ver
        when !@minor_allowed && (a_ver.segments[1] != b_ver.segments[1])
          b_ver <=> a_ver
        when @gems_to_update.patching_but_not_this_gem?(gem_name)
          b_ver <=> a_ver
        else
          a_ver <=> b_ver
        end
      end.tap do |result|
        if unlocking_gem
          if @gems_to_update.patching_gem?(gem_name)
            # this logic will keep a gem from updating past the patched version
            # if a more recent release (or minor, if enabled) version exists.
            # not sure if we want this special logic to remain or not.
            new_version = @gems_to_update.gem_patch_for(gem_name).new_version
            swap_version_to_end(specs, new_version, result) if new_version
          end
        else
          # make sure the current locked version is last in list.
          swap_version_to_end(specs, locked_version, result)
        end
      end
    end

    def swap_version_to_end(specs, version, result)
      spec_group = specs.detect { |s| s.first.version.to_s == version.to_s }
      if spec_group
        result.reject! { |s| s.first.version.to_s === version.to_s }
        result << spec_group
      end
    end
  end
end
