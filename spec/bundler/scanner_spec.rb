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

    it 'integration' do
      Dir.chdir(@bf.dir) do
        # This is a weird combination of:
        # - Fake advisory
        # - Real gem and its real versions @ rubygems.org

        # Scanner now uses the full Bundler install code - which has a lot
        # of hoops to jump through, and I found it easier to make that part
        # for real.

        ad = Bundler::Advise::Advisory.new(gem: 'rack', patched_versions: ['~> 1.4, >= 1.4.5'])
        gem_dir = File.join(@bf.dir, 'gems', 'rack')
        FileUtils.makedirs gem_dir
        File.open(File.join(gem_dir, 'rack-patch.yml'), 'w') { |f| f.print ad.to_yaml }

        GemfileLockFixture.create(@bf.dir,
                                  {rack: nil, git: '~> 1.2'},
                                  {rack: '1.4.4', git: '1.2.8'})

        Scanner.new.patch(advisory_db_path: @bf.dir, skip_bundler_advise: true)

        lockfile_spec_version('rack').should == '1.4.7'
        lockfile_spec_version('git').should == '1.2.8'
      end
    end

    it 'could offer option to include update parent gems with incompatible requirements'
    # the goal of applying a security patch is to get the security patch in place. The
    # tool could help id a parent gem that has an incompatible requirement with the
    # necessary patch version

  end
end
