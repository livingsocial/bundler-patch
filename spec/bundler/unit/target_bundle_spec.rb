require_relative '../../spec_helper'

def ruby_bin_version_or_higher(version)
  TargetBundle.version_greater_than_or_equal_to_other(RUBY_VERSION, version)
end

describe TargetBundle do
  before do
    @tmp_dir = File.join(__dir__, 'fixture')
    FileUtils.makedirs @tmp_dir
  end

  after do
    FileUtils.rmtree(@tmp_dir)
  end

  def gemfile_create(ruby_version)
    glf = GemfileLockFixture.new(dir: @tmp_dir, ruby_version: ruby_version)
    glf.create_gemfile
    yield @tmp_dir if block_given?
    glf.bundler_fixture
  end

  def lockfile_create(ruby_version)
    GemfileLockFixture.create(dir: @tmp_dir, ruby_version: ruby_version)
    yield @tmp_dir
  end

  it 'should default to current directory and Gemfile' do
    TargetBundle.new.tap do |bnd|
      bnd.dir.should == Dir.pwd
      bnd.gemfile.should == 'Gemfile'
    end
  end

  it 'should find ruby version from Gemfile' do
    # CI will run on older Bundler versions to verify this
    gemfile_create(RUBY_VERSION) do |dir|
      tb = TargetBundle.new(dir: dir)
      tb.ruby_version.to_s.should == RUBY_VERSION
    end
  end

  it 'should find ruby version from Gemfile or lockfile' do
    # CI will run on older Bundler versions to verify this
    lockfile_create(RUBY_VERSION) do |dir|
      tb = TargetBundle.new(dir: dir)
      if TargetBundle.bundler_version_or_higher('1.12.0')
        tb.ruby_version.to_s.should == "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
      else
        tb.ruby_version.to_s.should == RUBY_VERSION
      end
    end
  end

  it 'should behave with ruby requirement' do
    if TargetBundle.bundler_version_or_higher('1.12.0')
      conf = RbConfig::CONFIG
      lockfile_create("~> #{conf['MAJOR']}.#{conf['MINOR']}") do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_version.to_s.should == "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
      end
    else
      pending 'test irrelevant in versions prior to 1.12.0'
      fail
    end
  end

  it 'should find ruby version in .ruby-version file if Bundler too old' do
    if TargetBundle.bundler_version_or_higher('1.12.0')
      pending 'test irrelevant in versions >= 1.12.0'
      fail
    else
      rv = File.join(@tmp_dir, '.ruby-version')
      File.open(rv, 'w') { |f| f.puts '2.9.30' }
      gemfile_create(nil) do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_version.to_s.should == '2.9.30'
      end
    end
  end

  it 'should find ruby version in .ruby-version file if Bundler not too old but somehow does not have it' # maybe

  context 'ruby bin focused tests' do
    def tmp_dir(path)
      File.join(@tmp_dir, path)
    end

    before do
      %w(2.2.4 2.3.4 1.9.3-p551 2.1.10).each do |ver|
        dir = tmp_dir("versions/#{ver}/bin")
        FileUtils.makedirs dir
      end
    end

    it 'rbenv no patch-level'  do
      gemfile_create('2.1.10') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin(tmp_dir('/versions/2.3.4/bin')).should == tmp_dir('versions/2.1.10/bin')
      end
    end

    it 'rbenv from no patch-level to patch-level'  do
      gemfile_create('1.9.3p551') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin(tmp_dir('/versions/2.3.4/bin')).should == tmp_dir('versions/1.9.3-p551/bin')
      end
    end

    it 'rbenv from patch-level to no patch-level'  do
      gemfile_create('2.3.4') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin(tmp_dir('/versions/1.9.3-p551/bin')).should == tmp_dir('versions/2.3.4/bin')
      end
    end
    
    # haven't seen this in the wild, but it's easy to support
    it 'rbenv from patch-level no hyphen to no patch-level'  do
      gemfile_create('2.3.4') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin(tmp_dir('/versions/1.9.3p551/bin')).should == tmp_dir('versions/2.3.4/bin')
      end
    end
  end

  context 'gem_home' do
    it 'should work with no local config path' do
      gemfile_create('2.1.10')
      with_clean_env do
        tb = TargetBundle.new(dir: @tmp_dir)
        tb.gem_home.should match '2.1.10/lib/ruby/gems/2.1.0$'
      end
    end

    it 'should work with local config path' do
      # This used to have different functionality, but no longer does. Still need to doc that in
      # both cases we want the same result. (There's a chance that we'll NEED this, but not sure yet).
      bf = gemfile_create('2.1.10')
      bf.create_config(path: 'my-local-path')
      with_clean_env do
        tb = TargetBundle.new(dir: @tmp_dir)
        tb.gem_home.should match '2.1.10/lib/ruby/gems/2.1.0$'
      end
    end
  end

  it 'should detect when target ruby is different' do
    gemfile_create(RbConfig::CONFIG['RUBY_PROGRAM_VERSION'])
    with_clean_env do
      tb = TargetBundle.new(dir: @tmp_dir)
      tb.target_ruby_is_different?.should == false
    end
  end

  it 'should detect when target ruby is not different' do
    gemfile_create('2.1.10')
    with_clean_env do
      tb = TargetBundle.new(dir: @tmp_dir)
      tb.target_ruby_is_different?.should == true
    end
  end
end
