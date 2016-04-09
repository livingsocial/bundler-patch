require_relative '../spec_helper'

describe Scanner do
  before do
    @bf = BundlerFixture.new
    ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
  end

  after do
    ENV['BUNDLE_GEMFILE'] = nil
    @bf.clean_up unless @do_not_cleanup
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
    # you can re-use this case to help troubleshoot, just beware the big comment above.
    xit 'real case' do
      @do_not_cleanup = true
      Dir.chdir(@bf.dir) do
        %w(Gemfile Gemfile.lock).each do |fn|
          FileUtils.cp(File.join(File.expand_path(""), fn), File.join(@bf.dir), verbose: true)
        end

        Bundler.with_clean_env do
          system 'bundle install --path zz'

          ENV['DEBUG_PATCH_RESOLVER'] = '1'
          ENV['DEBUG_RESOLVER'] = '1'
          Scanner.new.patch
        end

        lockfile_spec_version('mail').should == '2.6.0'
      end
    end

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

    it 'patches rails 3_2 but not mail' do
      # mail cannot be patched with rails 3.2.x, and the clever hack of changing the locked_spec
      # for a patching gem, gets in the way here, because all other patches fail for the mail case
      # that we just have to live with anyway.

      ''.should == 'This test is not written yet'
    end
  end
end
