class GemfileLockFixture
  def self.create(dir:, gems: {}, locks: nil, gemfile: 'Gemfile', ruby_version: nil)
    bf = BundlerFixture.new(dir: dir, gemfile: gemfile)

    deps = gems.map { |name, version| bf.create_dependency(name.to_s, version) }
    bf.create_gemfile(gem_dependencies: deps, ruby_version: ruby_version)

    locks_or_gems = (locks || gems).map { |name, version| bf.create_dependency(name.to_s, version) }
    bf.create_lockfile(gem_dependencies: locks_or_gems, ruby_version: ruby_version)

    if block_given?
      Dir.chdir dir do
        yield dir
      end
    end

    bf
  end
end
