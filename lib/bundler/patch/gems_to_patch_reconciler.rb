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
      @vulnerable_patches.reject! { |gp| !@requested_patches.include?(gp) }
      @reconciled_patches.push(*((@vulnerable_patches + @requested_patches).uniq))
    end
  end
end



