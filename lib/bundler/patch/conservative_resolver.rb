module Bundler::Patch
  class ConservativeResolver < Bundler::Resolver
    attr_accessor :locked_specs, :gems_to_update, :strict, :minor_preferred, :prefer_minimal

    def initialize(index, source_requirements, base)
      # hack for 1.10 and 1.11 support
      case Bundler::Resolver.instance_method(:initialize).arity
      when 3
        super(index, source_requirements, base)
      when 4
        super(index, source_requirements, base, nil)
      end
    end

    def search_for(dependency)
      res = super(dependency)

      dep = dependency.dep unless dependency.is_a? Gem::Dependency

      @conservative_search_for ||= {}
      res = @conservative_search_for[dep] ||= begin
        gem_name = dep.name

        # An Array per version returned, different entries for different platforms.
        # We just need the version here so it's ok to hard code this to the first instance.
        locked_spec = @locked_specs[gem_name].first

        (@strict ?
          filter_specs(res, locked_spec) :
          sort_specs(res, locked_spec)).tap do |res|
          STDERR.puts debug_format_result(dep, res).inspect if ENV['DEBUG_PATCH_RESOLVER']
        end
      end

      # dup is important, in weird (large) cases Bundler will empty the result array corrupting the cache.
      # Bundler itself doesn't have this problem because the super search_for does a select on its cached
      # search results, effectively duping it.
      res.dup
    end

    def debug_format_result(dep, res)
      a = [dep.to_s,
           res.map { |sg| [sg.version, sg.dependencies_for_activated_platforms.map { |dp| [dp.name, dp.requirement.to_s] }] }]
      [a.first, a.last.map { |sg_data| [sg_data.first.version, sg_data.last.map { |aa| aa.join(' ') }] }]
    end

    def filter_specs(specs, locked_spec)
      res = specs.select do |sg|
        # SpecGroup is grouped by name/version, multiple entries for multiple platforms.
        # We only need the name, which will be the same, so hard coding to first is ok.
        gem_spec = sg.first

        if locked_spec
          gsv = gem_spec.version
          lsv = locked_spec.version

          must_match = @minor_preferred ? [0] : [0, 1]

          matches = must_match.map { |idx| gsv.segments[idx] == lsv.segments[idx] }
          (matches.uniq == [true]) ? gsv.send(:>=, lsv) : false
        else
          true
        end
      end

      sort_specs(res, locked_spec)
    end

    # reminder: sort still filters anything older than locked version
    def sort_specs(specs, locked_spec)
      return specs unless locked_spec
      gem_name = locked_spec.name
      locked_version = locked_spec.version

      filtered = specs.select { |s| s.first.version >= locked_version }

      filtered.sort do |a, b|
        a_ver = a.first.version
        b_ver = b.first.version
        gem_patch = @gems_to_update.gem_patch_for(gem_name)
        new_version = gem_patch ? gem_patch.new_version : nil
        case
        when a_ver.segments[0] != b_ver.segments[0]
          b_ver <=> a_ver
        when !@minor_preferred && (a_ver.segments[1] != b_ver.segments[1])
          b_ver <=> a_ver
        when @prefer_minimal && !@gems_to_update.unlocking_gem?(gem_name)
          b_ver <=> a_ver
        when @prefer_minimal && @gems_to_update.unlocking_gem?(gem_name) &&
          (![a_ver, b_ver].include?(locked_version) &&
            (!new_version || (new_version && a_ver >= new_version && b_ver >= new_version)))
          b_ver <=> a_ver
        else
          a_ver <=> b_ver
        end
      end.tap do |result|
        if @gems_to_update.unlocking_gem?(gem_name)
          gem_patch = @gems_to_update.gem_patch_for(gem_name)
          if gem_patch && gem_patch.new_version && @prefer_minimal
            move_version_to_end(specs, gem_patch.new_version, result)
          end
        else
          move_version_to_end(specs, locked_version, result)
        end
      end
    end

    def move_version_to_end(specs, version, result)
      spec_group = specs.detect { |s| s.first.version.to_s == version.to_s }
      if spec_group
        result.reject! { |s| s.first.version.to_s === version.to_s }
        result << spec_group
      end
    end
  end
end
