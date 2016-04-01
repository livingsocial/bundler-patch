# This is a cheap and easy one that pre-dates the bundler-fixture
# gem. Still using it for the Gemfile itself, since bundler-fixture
# doesn't include that yet. Though it prolly should.
# TODO: PR to bundler-fixture to include Gemfile
class GemfileLockFixture
  def self.create(dir:, gems: {}, locks: nil)
    fix = self.new(dir: dir, gems: gems, locks: locks).tap do |fix|
      fix.create_gemfile
      fix.create_gemfile_lock
    end
    if block_given?
      Dir.chdir fix.dir do
        yield fix.dir
      end
    end
    fix
  end

  attr_reader :dir, :gems, :locks

  def initialize(dir:, gems:, locks: nil)
    @dir = dir
    @gems = gems
    @locks = locks
  end

  def create_gemfile
    lines = []
    lines << "source 'https://rubygems.org'"
    @gems.each do |name, versions|
      line = "gem '#{name}'"
      Array(versions).each { |version| line << ", '#{version}'" } if versions
      lines << line
    end
    write_lines(lines, 'Gemfile')
    File.join(@dir, 'Gemfile')
  end

  def create_gemfile_lock
    bf = BundlerFixture.new(dir: @dir)
    specs = (@locks || @gems).map { |name, version| bf.create_dependency(name.to_s, version) }
    bf.create_lockfile(gem_dependencies: specs)
  end

  def write_lines(lines, filename)
    File.open(File.join(@dir, filename), 'w') { |f| f.puts lines }
  end
end

