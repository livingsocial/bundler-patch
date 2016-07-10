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
      # STDERR.puts "during sort_versions: #{debug_format_result(spec_groups.first.first.name, spec_groups).inspect}" if ENV["DEBUG_RESOLVER"]

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
        when new_version && @gems_to_update.unlocking_gem?(gem_name) && one_version_matches(new_version, a_ver, b_ver)
          sort_matching_to_end(new_version, a_ver, b_ver)
        else
          a_index <=> b_index # no change in current ordering
        end
      end.map { |a| a.last }
    end

    def neither_version_matches(match_version, a_ver, b_ver)
      !one_version_matches(match_version, a_ver, b_ver)
    end

    def both_versions_gt_or_equal_to_version(version, a_ver, b_ver)
      version && a_ver >= version && b_ver >= version
    end
  end
end
