require_relative '../spec_helper'

describe Scanner do
  before do
    @bf = BundlerFixture.new
  end

  after do
    @bf.clean_up
  end

  def lockfile_spec_version(gem_name)
    @bf.parsed_lockfile_spec(gem_name).version.to_s
  end

  context 'security patching' do
    before do
      ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
    end

    after do
      ENV['BUNDLE_GEMFILE'] = nil
    end

    def add_fake_advisory(gem:, patched_versions:)
      ad = Bundler::Advise::Advisory.new(gem: gem, patched_versions: patched_versions)
      gem_dir = File.join(@bf.dir, 'gems', gem)
      FileUtils.makedirs gem_dir
      File.open(File.join(gem_dir, "#{gem}-patch.yml"), 'w') { |f| f.print ad.to_yaml }
    end

    it 'integration' do
      Dir.chdir(@bf.dir) do
        add_fake_advisory(gem: 'rack', patched_versions: ['~> 1.4, >= 1.4.5'])

        PathedGemfileLockFixture.create(
          dir: @bf.dir,
          gems: {rack: nil, git: '~> 1.2'},
          locks: {rack: '1.4.4', git: '1.2.8'},
          sources: {rack: '1.4.7'}
        )

        Bundler.with_clean_env do
          Scanner.new.patch(advisory_db_path: @bf.dir, skip_bundler_advise: true)
        end

        lockfile_spec_version('rack').should == '1.4.7' # upgraded because fake advisory
        lockfile_spec_version('git').should == '1.2.8' # stays put because nothing to change it
      end
    end

    it 'could do better conservative update for patching to a security version'
    # when a gem is NOT unlocked, then Bundler itself locks the used version in place.
    # that's the point. `patch` currently only unlocks the vulnerable gems.
    # What `patch` should do is a special conservative update of ALL gems that truly
    # keeps everything at its current, a complete reverse of filter_specs, not a special
    # sort - just a complete reverse.

  end
end

class PathedGemfileLockFixture < GemfileLockFixture
  def self.create(dir:, gems: {}, locks: nil, sources: [])
    self.new(dir: dir, gems: gems, locks: locks).tap do |fix|
      fix.create_gemfile
      fix.create_gemfile_lock
      fix.make_fake_gems
      sources.each { |name, version| fix.make_fake_gem(name, version) }
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
    (@locks || @gems).map { |name, version| make_fake_gem(name, version) }
  end

  def make_fake_gem(name, version)
    gem_dir = File.join(@dir, 'pathed_gems')
    FileUtils.makedirs(gem_dir)
    contents = <<-CONTENT
Gem::Specification.new do |s|
  s.name            = "#{name}"
  s.version         = "#{version}"
  s.platform        = Gem::Platform::RUBY
  s.summary         = "Fake #{name}"
  s.authors         = %w(chrismo)

  # s.add_dependency 'bacon'
end
    CONTENT

    File.open(File.join(gem_dir, "#{name}-#{version}.gemspec"), 'w') { |f| f.print contents }
  end
end
