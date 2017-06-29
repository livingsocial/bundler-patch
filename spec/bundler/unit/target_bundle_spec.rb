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
    yield @tmp_dir
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
        if ruby_bin_version_or_higher('2.1.5')
          tb.ruby_version.to_s.should == RUBY_VERSION
        else
          tb.ruby_version.to_s.should == "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
        end
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
        if ruby_bin_version_or_higher('2.1.5')
          tb.ruby_version.to_s.should == RUBY_VERSION
        else
          tb.ruby_version.to_s.should == "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
        end
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
      File.open(rv, 'w') { |f| f.puts '2.3.4' }
      gemfile_create(nil) do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_version.to_s.should == '2.3.4'
      end
    end
  end

  it 'should find ruby version in .ruby-version file if Bundler not too old but somehow does not have it' # maybe

  context 'ruby bin focused tests' do
    it 'rbenv no patch-level'  do
      gemfile_create('2.2.4') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin('~/.rbenv/versions/2.3.4/bin').should == '~/.rbenv/versions/2.2.4/bin'
      end
    end

    it 'rbenv from no patch-level to patch-level'  do
      gemfile_create('1.9.3p551') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin('~/.rbenv/versions/2.3.4/bin').should == '~/.rbenv/versions/1.9.3-p551/bin'
      end
    end

    it 'rbenv from patch-level to no patch-level'  do
      gemfile_create('2.3.4') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin('~/.rbenv/versions/1.9.3-p551/bin').should == '~/.rbenv/versions/2.3.4/bin'
      end
    end
    
    # haven't seen in the wild, but should be able to support it easily
    it 'rbenv from patch-level no hyphen to no patch-level'  do
      gemfile_create('2.3.4') do |dir|
        tb = TargetBundle.new(dir: dir)
        tb.ruby_bin('~/.rbenv/versions/1.9.3p551/bin').should == '~/.rbenv/versions/2.3.4/bin'
      end
    end
  end
end
