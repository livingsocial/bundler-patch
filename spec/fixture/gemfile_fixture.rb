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

class PathedGemfileLockFixture < GemfileLockFixture
  def self.create(dir:, gems: {}, locks: nil, sources: [])
    self.new(dir: dir, gems: gems, locks: locks).tap do |fix|
      fix.create_gemfile
      fix.create_gemfile_lock
      fix.make_fake_gems
      Array(sources).each { |spec| fix.make_fake_gem(spec) }
    end
  end

  def create_gemfile
    lines = []
    dir = File.join(@dir, 'pathed_gems')
    lines << "path '#{dir}' do"
    @gems.each do |name, versions|
      line = "  gem '#{name}'"
      Array(versions).each { |version| line << ", '#{version}'" } if versions
      lines << line
    end
    lines << 'end'
    write_lines(lines, 'Gemfile')

    File.join(@dir, 'Gemfile')
  end

  def make_fake_gems
    (@locks || @gems).map { |name, version| make_fake_gem(create_spec(name, version)) }
  end

  def make_fake_gem(spec)
    name, version = [spec.name, spec.version]
    gem_dir = File.join(@dir, 'pathed_gems')
    FileUtils.makedirs(gem_dir)
    deps = spec.dependencies.map do |dep|
      "  s.add_dependency '#{dep.name}'".tap { |s| s << ", '#{dep.requirement}'" if dep.requirement }
    end

    contents = <<-CONTENT
Gem::Specification.new do |s|
  s.name            = "#{name}"
  s.version         = "#{version}"
  s.platform        = Gem::Platform::RUBY
  s.summary         = "Fake #{name}"
  s.authors         = %w(chrismo)

#{deps.join("\n")}
end
    CONTENT

    File.open(File.join(gem_dir, "#{name}-#{version}.gemspec"), 'w') { |f| f.print contents }
  end

  def create_spec(name, version, dependencies={})
    self.class.create_spec(name, version, dependencies)
  end

  def self.create_spec(name, version, dependencies={})
    Gem::Specification.new do |s|
      s.name = name
      s.version = Gem::Version.new(version)
      s.platform = 'ruby'
      dependencies.each do |name, requirement|
        s.add_dependency name, requirement
      end
    end
  end
end
