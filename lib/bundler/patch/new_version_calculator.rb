class NewVersionCalculator
  def initialize(old_version, patched_versions)
    @old_version = old_version
    @patched_versions = patched_versions
  end

  def run
    return old_version if patched_versions.include?(old_version)

    candidates[candidates.index(old_version) + 1]
  end

  private

    attr_reader :old_version, :patched_versions

    def candidates
      [
        patched_versions, old_version
      ].flatten(1).select { |version| first_part(version) == first_part(old_version) }.sort
    end

    def first_part(version)
      version.split(/\./).first
    end
end
