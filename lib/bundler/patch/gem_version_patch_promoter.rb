module Bundler::Patch
  class GemVersionPatchPromoter < Bundler::GemVersionPromoter
    attr_accessor :minimal, :gems_to_update

    private

    def sort_dep_specs(spec_groups, locked_spec)
      result = super(spec_groups, locked_spec)
      return result unless locked_spec

      @gem_name = locked_spec.name
      @locked_version = locked_spec.version
      gem_patch = @gems_to_update.gem_patch_for(@gem_name)
      @new_version = gem_patch ? gem_patch.new_version : nil

      return result unless @minimal || @new_version

      # STDERR.puts "during sort_versions: #{debug_format_result(spec_groups.first.first.name, result).inspect}" if ENV["DEBUG_RESOLVER"]

      # Custom sort_by-ish behavior to minimize index calls.
      result = result.map { |a| [result.index(a), a] }.sort do |(a_index, a), (b_index, b)|
        @a_ver = a.version
        @b_ver = b.version
        case
        when @minimal && unlocking_gem? &&
          (neither_version_matches(@locked_version) &&
            (!@new_version || both_versions_gt_or_equal_to_version(@new_version)))
          @b_ver <=> @a_ver
        else
          a_index <=> b_index # no change in current ordering
        end
      end.map { |a| a.last }

      post_sort(result)
    end

    def unlocking_gem?
      @gems_to_update.unlocking_gem?(@gem_name)
    end

    def one_version_matches(match_version)
      [@a_ver, @b_ver].include?(match_version)
    end

    def neither_version_matches(match_version)
      !one_version_matches(match_version)
    end

    def both_versions_gt_or_equal_to_version(version)
      version && @a_ver >= version && @b_ver >= version
    end

    # Sorting won't work properly for some specific arrangements to the end of the list because not
    # all versions are compared in quicksort and the result isn't deterministic.
    def post_sort(result)
      result = super(result)

      if @new_version && unlocking_gem? && segments_match(:major, @new_version, @locked_version)
        if @minimal || (!@minimal && result.last.version < @new_version)
          # This handles two cases:
          # - minimal doesn't want to go past requested new_version
          # - new_version is up a minor rev but level is :patch
          result = move_version_to_end(result, @new_version)
        end
      end

      result
    end

    def segments_match(level, a_ver, b_ver)
      index = [:major, :minor].index(level)
      a_ver.segments[index] == b_ver.segments[index]
    end
  end
end
