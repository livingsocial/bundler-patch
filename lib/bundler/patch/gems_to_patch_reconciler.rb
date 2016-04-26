class GemsToPatchReconciler
  attr_reader :reconciled_patches

  def initialize(vulnerable_patches, requested_patches=[])
    @vulnerable_patches = vulnerable_patches
    @requested_patches = requested_patches
    reconcile
  end

  private

  def reconcile
    @reconciled_patches = []
    unless @requested_patches.empty?
      requested_gem_names = @requested_patches.map(&:gem_name)
      # TODO: this would be simpler with set operators given proper <=> on GemPatch, right?
      @vulnerable_patches.reject! { |gp| !requested_gem_names.include?(gp.gem_name) }

      @reconciled_patches.push(*@vulnerable_patches)

      gem_patches_names = @reconciled_patches.map(&:gem_name)
      @requested_patches.each { |gp| @reconciled_patches << gp unless gem_patches_names.include?(gp.gem_name) }
    end
  end
end



