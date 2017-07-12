class GemfileLockFixture
  def self.create(dir:, gems: {}, locks: nil, gemfile: 'Gemfile', ruby_version: nil)
    glf = self.new(dir: dir, gems: gems, locks: locks, gemfile: gemfile, ruby_version: ruby_version)
    glf.create_gemfile
    glf.create_lockfile

    if block_given?
      Dir.chdir dir do
        yield dir
      end
    end

    glf.bundler_fixture
  end

  attr_reader :bundler_fixture

  def initialize(dir:, gems: {}, locks: nil, gemfile: 'Gemfile', ruby_version: nil)
    @dir = dir
    @gems = gems
    @locks = locks
    @gemfile = gemfile
    @ruby_version = ruby_version
    @bundler_fixture = BundlerFixture.new(dir: @dir, gemfile: @gemfile)
  end

  def create_gemfile
    deps = @gems.map { |name, version| @bundler_fixture.create_dependency(name.to_s, version) }
    @bundler_fixture.create_gemfile(gem_dependencies: deps, ruby_version: @ruby_version)
  end

  def create_lockfile
    locks_or_gems = (@locks || @gems).map { |name, version| @bundler_fixture.create_dependency(name.to_s, version) }
    @bundler_fixture.create_lockfile(gem_dependencies: locks_or_gems, ruby_version: @ruby_version)
  end
end
