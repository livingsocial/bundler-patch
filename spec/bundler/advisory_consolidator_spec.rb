require_relative '../spec_helper'

describe Scanner do
  before do
    @bf = BundlerFixture.new
  end

  after do
    @bf.clean_up
  end

  context 'advisory consolidator' do
    it 'should consolidate multiple advisories for same gem' do
      # rack has multiple advisories that if applied in a default
      # sequential order leave the gem on an insecure version.

      Dir.chdir(@bf.dir) do
        ads = [].tap do |a|
          [
            ['~> 1.1.6', '~> 1.2.8', '~> 1.3.10', '~> 1.4.5', '>= 1.5.2'],
            ['~> 1.4.5', '>= 1.5.2'],
            ['>= 1.6.2', '~> 1.5.4', '~> 1.4.6']
          ].each do |patch_group|
            a << Bundler::Advise::Advisory.new(gem: 'rack', patched_versions: patch_group)
          end
        end

        gem_dir = File.join(@bf.dir, 'gems', 'rack')
        FileUtils.makedirs gem_dir
        ads.each_with_index do |ad, i|
          File.open(File.join(gem_dir, "rack-patch-#{i}.yml"), 'w') { |f| f.print ad.to_yaml }
        end

        GemfileLockFixture.create(dir: @bf.dir, gems: {rack: '1.4.4'})

        all_ads = [Bundler::Advise::Advisories.new(dir: @bf.dir, repo: nil)]
        ac = AdvisoryConsolidator.new({}, all_ads)
        res = ac.vulnerable_gems
        res.first.patched_versions.should == %w(1.1.6 1.2.8 1.3.10 1.4.6 1.5.4 1.6.2)
        res.length.should == 1
      end
    end
  end
end
