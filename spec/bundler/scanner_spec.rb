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

    it 'adds new dependent gem on security upgrade' do
      Dir.chdir(@bf.dir) do
        add_fake_advisory(gem: 'foo', patched_versions: ['~> 1.4, >= 1.4.5'])
        add_fake_advisory(gem: 'nuu', patched_versions: ['~> 0.2, >= 0.2.2'])

        PathedGemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {foo: nil, bar: '~> 1.2'},
                     locks: {foo: '1.4.4', bar: '1.2.8'},
                     sources: [fix.create_spec(:foo, '1.4.7', {wat: '>= 1.2.0'}),
                               fix.create_spec(:wat, '1.2.3')])
        end

        Bundler.with_clean_env do
          Scanner.new.patch(advisory_db_path: @bf.dir, skip_bundler_advise: true)
        end

        lockfile_spec_version('foo').should == '1.4.7' # upgraded because fake advisory
        lockfile_spec_version('wat').should == '1.2.3' # foo upgrade brings new dependency

        lockfile_spec_version('bar').should == '1.2.8' # stays put because nothing to change it
      end
    end

    it 'upgrades insecure gem only in lockfile with parent needing upgrade too' do
      Dir.chdir(@bf.dir) do
        add_fake_advisory(gem: 'nuu', patched_versions: ['~> 0.2, >= 0.2.2'])

        PathedGemfileLockFixture.tap do |fix|
          fix.create(dir: @bf.dir,
                     gems: {tea: nil},
                     locks: {tea: '3.2.0', nuu: '0.1.0'},
                     sources: [fix.create_spec(:tea, '3.2.0', {nuu: '~> 0.1.0'}),
                               fix.create_spec(:tea, '3.2.3', {nuu: '>= 0.2'}),
                               fix.create_spec(:nuu, '0.2.2')])
        end

        Bundler.with_clean_env do
          #ENV['DEBUG_PATCH_RESOLVER'] = '1'
          #ENV['DEBUG_RESOLVER'] = '1'
          Scanner.new.patch(advisory_db_path: @bf.dir, skip_bundler_advise: true)
        end

        lockfile_spec_version('nuu').should == '0.2.2' # upgraded because fake advisory
        lockfile_spec_version('tea').should == '3.2.3' # upgraded to keep compatible with nuu 0.2.2
      end
    end

  end
end
