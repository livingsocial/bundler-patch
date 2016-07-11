module Bundler::Patch
  class GemVersionPatchPromoter < Bundler::GemVersionPromoter
    attr_accessor :minimal, :gems_to_update

    private

    def sort_dep_specs(spec_groups, locked_spec)
      result = super(spec_groups, locked_spec)
      return result unless locked_spec

      gem_name = locked_spec.name
      locked_version = locked_spec.version
      gem_patch = @gems_to_update.gem_patch_for(gem_name)
      new_version = gem_patch ? gem_patch.new_version : nil

      return result unless @minimal || new_version

      # TODO: says 'during' but will be output immediately, unlike the before/after in super class. :/
      # STDERR.puts "during sort_versions: #{debug_format_result(spec_groups.first.first.name, result).inspect}" if ENV["DEBUG_RESOLVER"]

      # Custom sort_by-ish behavior to minimize index calls.
      result.map { |a| [result.index(a), a] }.sort do |(a_index, a), (b_index, b)|
        a_ver = a.version
        b_ver = b.version
        case
        when @minimal && @gems_to_update.unlocking_gem?(gem_name) &&
          (neither_version_matches(locked_version, a_ver, b_ver) &&
            (!new_version || both_versions_gt_or_equal_to_version(new_version, a_ver, b_ver)))
          b_ver <=> a_ver
        when @minimal && @gems_to_update.unlocking_gem?(gem_name) && one_version_matches(new_version, a_ver, b_ver)
          sort_matching_to_end(new_version, a_ver, b_ver)
        else
          a_index <=> b_index # no change in current ordering
        end
      end.map { |a| a.last }.tap do |res|
        # This usage of move_version_to_end is to handle an edge case: when a new_version is up
        # a minor version, but the level is only :patch.
        #
        # Inline sorting this isn't working reliably because we're working with an already sorted array
        # in Bundler proper, and not all versions are compared in quicksort of course. One specific
        # comparison is required though to sort this to the end and it may not always happen. This code
        # ensures it happens.
        if new_version && @gems_to_update.unlocking_gem?(gem_name) && !@minimal && res.last.version < new_version
          move_version_to_end(spec_groups, new_version, res)
        end
      end
    end

    def neither_version_matches(match_version, a_ver, b_ver)
      !one_version_matches(match_version, a_ver, b_ver)
    end

    def both_versions_gt_or_equal_to_version(version, a_ver, b_ver)
      version && a_ver >= version && b_ver >= version
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
