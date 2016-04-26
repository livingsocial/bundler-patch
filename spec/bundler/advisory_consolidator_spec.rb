require_relative '../spec_helper'

describe AdvisoryConsolidator do
  before do
    @bf = BundlerFixture.new
    @inc = 1
    ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
  end

  after do
    ENV['BUNDLE_GEMFILE'] = nil
    @bf.clean_up
  end

  def add_fake_advisory(gem:, patched_versions:)
    ad = Bundler::Advise::Advisory.new(gem: gem, patched_versions: patched_versions)
    gem_dir = File.join(@bf.dir, 'gems', gem)
    FileUtils.makedirs gem_dir
    File.open(File.join(gem_dir, "#{gem}-patch-#{@inc += 1}.yml"), 'w') { |f| f.print ad.to_yaml }
  end

  def all_ads
    [Bundler::Advise::Advisories.new(dir: @bf.dir, repo: nil)]
  end

  context 'advisory consolidator' do
    it 'should consolidate multiple advisories for same gem' do
      # rack has multiple advisories that if applied in a default
      # sequential order leave the gem on an insecure version.

      Dir.chdir(@bf.dir) do
        [
          ['~> 1.1.6', '~> 1.2.8', '~> 1.3.10', '~> 1.4.5', '>= 1.5.2'],
          ['~> 1.4.5', '>= 1.5.2'],
          ['>= 1.6.2', '~> 1.5.4', '~> 1.4.6']
        ].each do |patch_group|
          add_fake_advisory(gem: 'rack', patched_versions: patch_group)
        end

        GemfileLockFixture.create(dir: @bf.dir, gems: {rack: '1.4.4'})

        ac = AdvisoryConsolidator.new({}, all_ads)
        res = ac.vulnerable_gems
        res.first.patched_versions.should == %w(1.1.6 1.2.8 1.3.10 1.4.6 1.5.4 1.6.2)
        res.length.should == 1
      end
    end

    it 'should cope with a disallowed major version increment appropriately' do
      Dir.chdir(@bf.dir) do
        add_fake_advisory(gem: 'foo', patched_versions: ['>= 3.2.0'])

        GemfileLockFixture.create(dir: @bf.dir, gems: {foo: '2.2.8'})

        ac = AdvisoryConsolidator.new({}, all_ads)
        gem_patches = ac.patch_gemfile_and_get_gem_specs_to_patch
        gem_patches.length.should == 1
        gp = gem_patches.first
        gp.gem_name.should == 'foo'
        gp.old_version.to_s.should == '2.2.8'
        gp.patched_versions.should == ['3.2.0']
      end
    end
  end

  context 'GemPatch' do
    it 'should be equal if gem_name matches' do
      (GemPatch.new(gem_name: 'foo') == GemPatch.new(gem_name: 'foo')).should be true
    end

    it 'should not be equal if gem_name does not match' do
      GemPatch.new(gem_name: 'foo').should_not == GemPatch.new(gem_name: 'bar')
    end

    it 'should be uniq-able' do
      [GemPatch.new(gem_name: 'foo'), GemPatch.new(gem_name: 'foo')].uniq.length.should == 1
    end
  end
end
