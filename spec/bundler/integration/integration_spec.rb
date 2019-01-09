require_relative '../../spec_helper'

describe CLI do
  before do
    setup_bundler_fixture
  end

  def setup_bundler_fixture(gemfile: 'Gemfile')
    @bf = BundlerFixture.new(dir: File.expand_path('../../../tmp', __dir__), gemfile: gemfile)
  end

  after do
    @bf.clean_up
    ENV['BUNDLE_GEMFILE'] = nil
  end

  def lockfile_spec_version(gem_name)
    @bf.parsed_lockfile_spec(gem_name).version.to_s
  end

  context 'integration tests' do
    it 'single gem with vulnerability' do
      Dir.chdir(@bf.dir) do
        # TODO: tap then create is a no-op. Replace with just create. And it returns a @bf instance, so no need for two?
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '2.1.1'
      end
    end

    # There's SO much global state in SO any nooks and crannies, even with 1.15 Bundler.reset! and additional hacks
    # like Gem.instance_variable_set("@paths", nil) (which I tried below), there's just no good way to inline a
    # call back into Bundler to make it clean. with_clean_env plus backtick seems to be the best.
    it 'single gem with vulnerability with --gemfile option' do
      bf = GemfileLockFixture.create(dir: @bf.dir,
                                     gems: {rack: nil, addressable: nil},
                                     locks: {rack: '1.4.1', addressable: '2.1.1'})
      bf.create_config(path: 'local_path')

      with_clean_env do
        bundler_patch(gemfile: File.join(@bf.dir, 'Gemfile'), gems_to_update: ['rack'])
      end

      lockfile_spec_version('rack').should == '1.4.7'
      lockfile_spec_version('addressable').should == '2.1.1'

      with_clean_env do
        Dir.chdir(bf.dir) do
          contents = `bundle show rack`
          contents.should match /local_path/
        end
      end
    end

    it 'all gems, one with vulnerability' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '2.1.2'
      end
    end

    it 'all gems, one with vulnerability, -v flag' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(vulnerable_gems_only: true)
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '2.1.1'
      end
    end

    it 'all gems, no vulnerability, -v flag, should do nothing' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {addressable: nil},
                     locks: {addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(vulnerable_gems_only: true)
        end

        lockfile_spec_version('addressable').should == '2.1.1'
      end
    end

    it 'single gem, minor allowed' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '0.2.0', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(minor: true, gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '0.9.1'
        lockfile_spec_version('addressable').should == '2.1.1'
      end
    end

    it 'all gems, one with vulnerability, strict mode' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(strict: true)
        end

        # only diff here would be if a dependency of rack would otherwise go up a minor
        # or major version. since there is no dependency here, this is the same result
        # with or without strict flag. this integration test inadequate to demonstrate
        # the difference.
        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '2.1.2'
      end
    end

    it 'single gem with vulnerability, strict mode' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(strict: true, gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('addressable').should == '2.1.1'
      end
    end

    it 'single gem with vulnerability, minimal mode' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(minimal: true, gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.6'
        lockfile_spec_version('addressable').should == '2.1.1'
      end
    end

    it 'single gem with vulnerability updates cache' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        # Ensure vendor/cache exists
        FileUtils.makedirs File.join(@bf.dir, 'vendor', 'cache')

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          # Bundler.reset! is only in 1.13, but these are the only bits we need reset for this to work:
          %w(root load).each { |name| Bundler.instance_variable_set("@#{name}", nil) }
          CLI.new.patch(strict_updates: true, gems_to_update: ['rack'])
        end

        lockfile_spec_version('rack').should == '1.4.7'
        File.exist?(File.join(@bf.dir, 'vendor', 'cache', 'rack-1.4.7.gem')).should == true
      end
    end

    it 'single gem with vulnerability, requiring minor upgrade non-minimal' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {bson: nil},
                     locks: {bson: '1.11.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(gems_to_update: ['bson'])
        end

        lockfile_spec_version('bson').should == '1.12.3'
      end
    end

    it 'single gem with vulnerability, requiring minor upgrade minimal' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {bson: nil},
                     locks: {bson: '1.11.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(prefer_minimal: true, gems_to_update: ['bson'])
        end

        lockfile_spec_version('bson').should == '1.12.3'
      end
    end

    it 'single gem, other with vulnerability, strict mode' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(strict_updates: true, gems_to_update: ['addressable'])
        end

        lockfile_spec_version('rack').should == '1.4.1'
        lockfile_spec_version('addressable').should == '2.1.2'
      end
    end

    it 'single gem with change to Gemfile with custom Gemfile name' do
      gemfile_base = 'Custom.gemfile'
      gemfile_name = File.join(@bf.dir, gemfile_base)

      setup_bundler_fixture(gemfile: gemfile_base)

      GemfileLockFixture.tap do |fix|
        fix.create(dir: @bf.dir,
                   gems: {rack: '1.4.1'},
                   locks: {rack: '1.4.1'},
                   gemfile: gemfile_base)
      end

      with_clean_env do
        CLI.new.patch(gemfile: gemfile_name)
      end

      gemfile_contents = File.read(gemfile_name)
      gemfile_contents.should include "gem 'rack', '1.4.6'"
      lockfile_spec_version('rack').should == '1.4.6'
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
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        res = nil
        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          res = with_captured_stdout do
            CLI.new.patch(list: true)
          end
        end

        res.should =~ /Detected vulnerabilities/
        res.should =~ /#{Regexp.escape('rack ["1.6.2", "1.5.4", "1.4.6", "2.0.6", "1.1.6", "1.2.8", "1.3.9"]')}/
      end
    end

    it 'allows optional config of ruby-advisory-db' do
      Dir.chdir(@bf.dir) do
        GemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {rack: nil, addressable: nil},
                     locks: {rack: '1.4.1', addressable: '2.1.1'})
        end

        target_dir = File.join(@bf.dir, '.foobar')
        File.exist?(File.join(target_dir, 'gems')).should eq false

        with_clean_env do
          ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
          CLI.new.patch(gems_to_update: ['rack'], ruby_advisory_db_path: target_dir)
        end

        File.exist?(File.join(target_dir, 'gems')).should eq true
      end
    end
  end

  context 'ruby patch' do
    before do
      @current_ruby_api = RbConfig::CONFIG['ruby_version']
      @current_ruby = RUBY_VERSION
    end

    it 'update mri ruby' do
      Dir.chdir(@bf.dir) do
        File.open('Gemfile', 'w') { |f| f.puts "ruby '#{@current_ruby_api}'" }
        CLI.new.patch(ruby: true, rubies: [@current_ruby])
        File.read('Gemfile').chomp.should == "ruby '#{@current_ruby}'"
      end
    end

    it 'updates ruby version in custom Gemfile' do
      fn = File.join(@bf.dir, 'Custom.gemfile')
      File.open(fn, 'w') { |f| f.puts "ruby '#{@current_ruby_api}'" }
      CLI.new.patch(ruby: true, rubies: [@current_ruby], gemfile: fn)
      File.read(fn).chomp.should == "ruby '#{@current_ruby}'"
    end
  end
end
