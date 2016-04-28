require_relative '../../spec_helper'

class BundlerFixture
  def gemfile_filename
    File.join(@dir, 'Gemfile')
  end

  def gemfile_contents
    File.read(gemfile_filename)
  end
end

describe CLI do
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

  context 'integration tests' do
    it 'single gem requested with vulnerability' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {'rack': nil, addressable: nil},
                     locks: {'rack': '1.4.1', addressable: '1.0.1'})
        end

        Bundler.with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(gems_to_update: ['rack'])
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
          CLI.new.patch
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
          ENV['DEBUG_PATCH_RESOLVER']= '1'
          CLI.new.patch(vulnerable_gems_only: true)
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
          CLI.new.patch(minor_preferred: true, gems_to_update: ['rack'])
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
          CLI.new.patch(strict: true)
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
          CLI.new.patch(strict: true, gems_to_update: ['rack'])
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
          CLI.new.patch(strict: true, gems_to_update: ['addressable'])
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
            CLI.new.patch(list: true)
          end
        end

        res.should =~ /Detected vulnerabilities/
        res.should =~ /#{Regexp.escape('rack ["1.6.2", "1.5.4", "1.4.6", "1.1.6", "1.2.8", "1.3.9"]')}/
      end
    end
  end
end
