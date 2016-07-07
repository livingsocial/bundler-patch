module Bundler::Patch
  class GemVersionPatchPromoter < Bundler::GemVersionPromoter
    attr_accessor :minimal, :gems_to_update

    # def initialize(locked_specs = SpecSet.new([]), unlock_gems = [])
    #   super(locked_specs, unlock_gems)
    # end

  private

    def sort_dep_specs(spec_groups, locked_spec)
      result = super(spec_groups, locked_spec)
      return result unless locked_spec
      return result unless @minimal

      gem_name = locked_spec.name
      locked_version = locked_spec.version

      result.sort do |a, b|
        a_ver = a.version
        b_ver = b.version
        gem_patch = @gems_to_update.gem_patch_for(gem_name)
        new_version = gem_patch ? gem_patch.new_version : nil
        case
        # when prefer_minimal && !@gems_to_update.unlocking_gem?(gem_name)
        #   b_ver <=> a_ver
        when @minimal && @gems_to_update.unlocking_gem?(gem_name) &&
          (![a_ver, b_ver].include?(locked_version) &&
            (!new_version || (new_version && a_ver >= new_version && b_ver >= new_version)))
          b_ver <=> a_ver
        else
          0 # don't change
        end
      end.tap do |result|
        # default :major behavior in Bundler does not do this
        # unless major?
        #   unless unlocking_gem?(gem_name)
        #     move_version_to_end(spec_groups, locked_version, result)
        #   end
        # end
      end
    end
  end
end
