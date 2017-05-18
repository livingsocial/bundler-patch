# This is a cheap and easy one that pre-dates the bundler-fixture
# gem. Still using it for the Gemfile itself, since bundler-fixture
# doesn't include that yet. Though it prolly should.
# TODO: PR to bundler-fixture to include Gemfile
class GemfileLockFixture
  def self.create(dir:, gems: {}, locks: nil, sources: [], gemfile: 'Gemfile')
    fix = self.new(dir: dir, gems: gems, locks: locks, sources: sources, gemfile: gemfile).tap do |fix|
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

  def initialize(dir:, gems:, locks: nil, sources: [], gemfile: gemfile)
    @dir = dir
    @gems = gems
    @locks = locks
    @sources = sources
    @gemfile = gemfile
  end

  def create_gemfile
    lines = []
    lines << "source 'https://rubygems.org'"
    @sources.each { |s| lines << "source '#{s}'" }
    @gems.each do |name, versions|
      line = "gem '#{name}'"
      Array(versions).each { |version| line << ", '#{version}'" } if versions
      lines << line
    end
    write_lines(lines, @gemfile)
    File.join(@dir, @gemfile)
  end

  def create_gemfile_lock
    bf = BundlerFixture.new(dir: @dir, gemfile: @gemfile)
    specs = (@locks || @gems).map { |name, version| bf.create_dependency(name.to_s, version) }
    bf.create_lockfile(gem_dependencies: specs)
  end

  def write_lines(lines, filename)
    File.open(File.join(@dir, filename), 'w') { |f| f.puts lines }
  end
end

# Pathed cannot realistically fake remote sources, however, cuz too much special sauce in Bundler. It will
# more enthusiastically unlock gems in pathed sources, and therefore won't replicate remote source behavior.
# The only reason this exists was an attempt at that (seemed to be working well for a while but I was
# fooling myself and I didn't believe it.)
class PathedGemfileLockFixture < GemfileLockFixture
  def self.create(dir:, gems: {}, locks: nil, sources: [])
    self.new(dir: dir, gems: gems, locks: locks).tap do |fix|
      fix.create_gemfile
      fix.create_gemfile_lock
      fix.make_fake_gems
      Array(sources).flatten.each { |spec| fix.make_fake_gem(spec) }
    end
  end

  def create_gemfile
    lines = []
    @gems.each do |name, versions|
      line = "gem '#{name}'"
      Array(versions).each { |version| line << ", '#{version}'" } if versions
      line << ", :path => '#{da_gem_dir = gem_dir(create_spec(name, versions ? Array(versions).first : ''))}'"
      lines << line
    end
    write_lines(lines, 'Gemfile')

    File.join(@dir, 'Gemfile')
  end

  def make_fake_gems
    (@locks || @gems).map { |name, version| make_fake_gem(create_spec(name, version)) }
  end

  def make_fake_gem(spec)
    name, version = [spec.name, spec.version]
    FileUtils.makedirs(gem_dir(spec))
    deps = spec.dependencies.map do |dep|
      "  s.add_dependency '#{dep.name}'".tap do |s|
        s << ", #{dep.requirement.requirements.map { |op, v| "'#{op} #{v}'" }.join(', ')}" if dep.requirement
      end
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

    gemspec_fn = File.join(gem_dir(spec), "#{name}-#{version}.gemspec")
    puts "Creating #{gemspec_fn}"
    File.open(gemspec_fn, 'w') { |f| f.print contents }
  end

  def gem_dir(spec)
    File.join(@dir, 'pathed_gems', spec.name.to_s, spec.version.to_s)
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
        s.add_dependency name, requirement.split(',')
      end
    end
  end

  def self.create_specs(name, versions, dependencies={})
    Array(versions).map { |v| create_spec(name, v, dependencies) }
  end
end
