require_relative '../spec_helper'

class BundlerFixture
  def gemfile_filename
    File.join(@dir, 'Gemfile')
  end

  def gemfile_contents
    File.read(gemfile_filename)
  end
end

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

          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          ENV['DEBUG_PATCH_RESOLVER'] = '1'
          ENV['DEBUG_RESOLVER'] = '1'
          Scanner.new.patch
        end

        lockfile_spec_version('mail').should == '2.6.0'
      end
    end

    it 'single gem requested with vulnerability' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          Scanner.new.patch(gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '1.0.1'
      end
    end

    it 'all gems, one with vulnerability' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          Scanner.new.patch
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '1.0.4'
      end
    end

    it 'all gems, one with vulnerability, -i flag' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          Scanner.new.patch(vulnerable_gems_only: true)
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '1.0.1'
      end
    end

    it 'single gem, minor allowed' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '0.2.0', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          Scanner.new.patch(minor_allowed: true, gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '0.9.1'
        lockfile_spec_version('addressable').should == '1.0.1'
      end
    end

    it 'all gems, one with vulnerability, strict mode' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          Scanner.new.patch(strict: true)
        end

        # only diff here would be if a dependency of rack would otherwise go up a minor
        # or major version. since there is no dependency here, this is the same result
        # with or without strict flag. this integration test inadequate to demonstrate
        # the difference.
        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '1.0.4'
      end
    end

    it 'single gem with vulnerability, strict mode' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          Scanner.new.patch(strict: true, gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '1.0.1'
      end
    end

    it 'single gem, other with vulnerability, strict mode' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          Scanner.new.patch(strict: true, gems_to_update: ['addressable'])
        end

        lockfile_spec_version('rack').should == '1.4.1'
        lockfile_spec_version('addressable').should == '1.0.4'
      end
    end

    def with_captured_stdout
      begin
        old_stdout = $stdout
        $stdout = StringIO.new('', 'w')
        yield
        $stdout.string
      ensure
        $stdout = old_stdout
      end
    end

    it 'lists vulnerable gems' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        res = nil
        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          res = with_captured_stdout do
            Scanner.new.patch(list: true)
          end
        end

        res.should =~ /Detected vulnerabilities/
        res.should =~ /#{Regexp.escape('rack ["1.6.2", "1.5.4", "1.4.6", "1.1.6", "1.2.8", "1.3.9"]')}/
      end
    end
  end
end
