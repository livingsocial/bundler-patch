class NewVersionCalculator
  def initialize(old_version, patched_versions)
    @old_version = old_version
    @patched_versions = patched_versions
  end

  def run
    return old_version if patched_versions.include?(old_version)

    patched_versions << old_version
    patched_versions.sort!
    patched_versions.delete_if { |v| v.split(/\./).first != old_version.split(/\./).first }

    patched_versions[patched_versions.index(old_version) + 1]
  end

  private

    attr_reader :old_version, :patched_versions
end
