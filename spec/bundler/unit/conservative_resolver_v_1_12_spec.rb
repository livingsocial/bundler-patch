require_relative '../../spec_helper'

describe ConservativeResolverV1_12 do
  before do
    skip 'Testing against Bundler >= 1.13' if bundler_1_13?
    @bf = BundlerFixture.new
  end

  after do
    @bf.clean_up
  end

  context 'conservative resolver' do
    def create_specs(gem_name, versions)
      @bf.create_specs(gem_name, versions).map { |s| Array(s) }
    end

    def locked(gem_name, version)
      @bf.create_spec(gem_name, version)
    end

    def versions(result)
      result.flatten.map(&:version).map(&:to_s)
    end

    def unlocking(options={})
      @cr.gems_to_update = GemsToPatch.new(GemPatch.new(gem_name: 'foo'))
    end

    def keep_locked(options={})
      @cr.gems_to_update = GemsToPatch.new(GemPatch.new(gem_name: 'bar'))
    end

    before do
      @cr = ConservativeResolverV1_12.new(nil, {}, [])
      @cr.gems_to_update = GemsToPatch.new(nil)
    end

    # Rightmost (highest array index) in result is most preferred.
    # Leftmost (lowest array index) in result is least preferred.
    # `create_specs` has all version of gem in index.
    # `locked` is the version currently in the .lock file.
    #
    # In default (not strict) mode, all versions in the index will
    # be returned, allowing Bundler the best chance to resolve all
    # dependencies, but sometimes resulting in upgrades that some
    # would not consider conservative.
    context 'filter specs (strict) (minor not allowed)' do
      it 'when keeping locked, keep current, next release' do
        keep_locked
        res = @cr.filter_specs(create_specs('foo', %w(1.7.8 1.7.9 1.8.0)),
                               locked('foo', '1.7.8'))
        versions(res).should == %w(1.7.9 1.7.8)
      end

      it 'when unlocking prefer next release first' do
        unlocking
        res = @cr.filter_specs(create_specs('foo', %w(1.7.8 1.7.9 1.8.0)),
                               locked('foo', '1.7.8'))
        versions(res).should == %w(1.7.8 1.7.9)
      end

      it 'when unlocking keep current when already at latest release' do
        unlocking
        res = @cr.filter_specs(create_specs('foo', %w(1.7.9 1.8.0 2.0.0)),
                               locked('foo', '1.7.9'))
        versions(res).should == %w(1.7.9)
      end
    end

    context 'filter specs (strict) (minor preferred)' do
      it 'should have specs'
    end

    context 'sort specs (not strict) (minor not allowed)' do
      it 'when not unlocking, same order but make sure locked version is most preferred to stay put' do
        keep_locked
        res = @cr.sort_specs(create_specs('foo', %w(1.7.6 1.7.7 1.7.8 1.7.9 1.8.0 1.8.1 2.0.0 2.0.1)),
                             locked('foo', '1.7.7'))
        versions(res).should == %w(2.0.0 2.0.1 1.8.0 1.8.1 1.7.8 1.7.9 1.7.7)
      end

      it 'when unlocking favor next release, then current over minor increase' do
        unlocking
        res = @cr.sort_specs(create_specs('foo', %w(1.7.7 1.7.8 1.7.9 1.8.0)),
                             locked('foo', '1.7.8'))
        versions(res).should == %w(1.8.0 1.7.8 1.7.9)
      end

      it 'when unlocking do proper integer comparison, not string' do
        unlocking
        res = @cr.sort_specs(create_specs('foo', %w(1.7.7 1.7.8 1.7.9 1.7.15 1.8.0)),
                             locked('foo', '1.7.8'))
        versions(res).should == %w(1.8.0 1.7.8 1.7.9 1.7.15)
      end

      it 'leave current when unlocking but already at latest release' do
        unlocking
        res = @cr.sort_specs(create_specs('foo', %w(1.7.9 1.8.0 2.0.0)),
                             locked('foo', '1.7.9'))
        versions(res).should == %w(2.0.0 1.8.0 1.7.9)
      end

      it 'when new_version specified, still update to most recent release past patched new_version' do
        # new_version can be specified when gem is vulnerable
        @cr.gems_to_update = GemsToPatch.new(GemPatch.new(gem_name: 'foo', new_version: '1.7.8'))
        versions = %w(1.7.5 1.7.7 1.7.8 1.7.9 1.8.0 2.0.0 2.1.0 3.0.0 3.0.1 3.1.0)
        res = @cr.sort_specs(create_specs('foo', versions),
                             locked('foo', '1.7.5'))
        versions(res).should == %w(3.1.0 3.0.0 3.0.1 2.1.0 2.0.0 1.8.0 1.7.5 1.7.7 1.7.8 1.7.9)
      end

      it 'when new_version specified, with prefer minimal, make sure to at least get to new_version' do
        @cr.gems_to_update = GemsToPatch.new(GemPatch.new(gem_name: 'foo', new_version: '1.7.7'))
        @cr.prefer_minimal = true
        versions = %w(1.7.5 1.7.6 1.7.7 1.7.8 1.7.9 1.8.0 2.0.0 2.1.0 3.0.0 3.0.1 3.1.0)
        res = @cr.sort_specs(create_specs('foo', versions),
                             locked('foo', '1.7.5'))
        versions(res).should == %w(3.1.0 3.0.1 3.0.0 2.1.0 2.0.0 1.8.0 1.7.5 1.7.6 1.7.9 1.7.8 1.7.7)
      end

      it 'when prefer_minimal, and not updating this gem, order is strictly oldest to newest' do
        keep_locked
        @cr.prefer_minimal = true
        versions = %w(1.7.5 1.7.8 1.7.9 1.8.0 2.0.0 2.1.0 3.0.0 3.0.1 3.1.0)
        res = @cr.sort_specs(create_specs('foo', versions),
                             locked('foo', '1.7.5'))
        versions(res).should == versions.reverse
      end

      it 'when prefer_minimal, and updating this gem, order is oldest to newest except current' do
        unlocking
        @cr.prefer_minimal = true
        versions = %w(1.7.5 1.7.8 1.7.9 1.8.0 2.0.0 2.1.0 3.0.0 3.0.1 3.1.0)
        res = @cr.sort_specs(create_specs('foo', versions),
                             locked('foo', '1.7.5'))
        versions(res).should == %w(3.1.0 3.0.1 3.0.0 2.1.0 2.0.0 1.8.0 1.7.5 1.7.9 1.7.8)
      end
    end

    context 'sort specs (not strict) (minor allowed)' do
      it 'when unlocking favor next release, then minor increase over current' do
        unlocking
        @cr.minor_preferred = true
        res = @cr.sort_specs(create_specs('foo', %w(0.2.0 0.3.0 0.3.1 0.9.0 1.0.0 2.0.0 2.0.1)),
                             locked('foo', '0.2.0'))
        versions(res).should == %w(2.0.0 2.0.1 1.0.0 0.2.0 0.3.0 0.3.1 0.9.0)
      end

      it 'new version specified'

      it 'new version specified, prefer_minimal'
    end

    context 'caching search results' do
      before do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo')],
          source_specs: [@bf.create_spec('foo', '2.4.0')], ensure_sources: false, update_gems: 'foo')
        index = bundler_def.instance_variable_get('@index')
        @cr = ConservativeResolverV1_12.new(index, {}, Bundler::SpecSet.new([]))
        @cr.locked_specs = {'foo' => [@bf.create_spec('foo', '2.4.0')]}
        @cr.gems_to_update = GemsToPatch.new([])
      end

      it 'should dup the output to protect the cache' do
        # Bundler will (somewhere) do this on occasion during a large resolution. Let's protect against it.
        dep = Bundler::DepProxy.new(Gem::Dependency.new('foo', '>= 0'), 'ruby')
        res = @cr.search_for(dep)
        res.clear
        @cr.search_for(dep).should_not == []
      end
    end
  end
end
