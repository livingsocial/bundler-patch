require_relative '../spec_helper'

describe Scanner do
  before do
    @bf = BundlerFixture.new
    ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
  end

  after do
    ENV['BUNDLE_GEMFILE'] = nil
    @bf.clean_up
  end

  def lockfile_spec_version(gem_name)
    @bf.parsed_lockfile_spec(gem_name).version.to_s
  end

  # NOTE: doing complicated real life cases from within specs can still result
  # in weird results inside Bundler. It can be a nice way to try and debug
  # a real case, but make sure and keep double checking the same behavior is
  # occurring outside of RSpec and this tmpdir setup, or you might drive u-self
  # crayz. The following tests are nice and simple to at least exercise the
  # basic mechanisms, but are not intended to be comprehensive.
  context 'integration tests' do
    it 'conservative update single' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          Scanner.new.update(gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '1.0.1'
      end
    end

    it 'conservative update all' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          Scanner.new.update
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '1.0.4'
      end
    end

    it 'conservative update one, minor allowed' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '0.2.0', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          Scanner.new.update(minor_allowed: true, gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '0.9.1'
        lockfile_spec_version('addressable').should == '1.0.1'
      end
    end

    it 'patches one' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          Scanner.new.patch(gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.6'
        lockfile_spec_version('addressable').should == '1.0.1'
      end
    end
  end
end
