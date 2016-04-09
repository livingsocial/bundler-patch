require_relative '../spec_helper'

describe Scanner do
  before do
    @bf = BundlerFixture.new
  end

  after do
    @bf.clean_up
  end

  context 'conservative resolver' do
    def create_specs(gem_name, versions)
      versions.map do |v|
        @bf.create_spec(gem_name, v)
      end.map { |s| [s] }
    end

    def locked(gem_name, version)
      @bf.create_spec(gem_name, version)
    end

    def versions(result)
      result.flatten.map(&:version).map(&:to_s)
    end

    def unlocking
      true
    end

    def keep_locked
      false
    end

    before do
      @cr = ConservativeResolver.new(nil, nil, [])
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
        res = @cr.filter_specs(create_specs('foo', %w(1.7.8 1.7.9 1.8.0)),
                               keep_locked, locked('foo', '1.7.8'))
        versions(res).should == %w(1.7.9 1.7.8)
      end

      it 'when unlocking prefer next release first' do
        res = @cr.filter_specs(create_specs('foo', %w(1.7.8 1.7.9 1.8.0)),
                               unlocking, locked('foo', '1.7.8'))
        versions(res).should == %w(1.7.8 1.7.9)
      end

      it 'when unlocking keep current when already at latest release' do
        res = @cr.filter_specs(create_specs('foo', %w(1.7.9 1.8.0 2.0.0)),
                               unlocking, locked('foo', '1.7.9'))
        versions(res).should == %w(1.7.9)
      end
    end

    context 'sort specs (not strict) (minor not allowed)' do
      it 'when not unlocking order by current, next release, next minor' do
        res = @cr.sort_specs(create_specs('foo', %w(1.7.6 1.7.7 1.7.8 1.7.9 1.8.0 2.0.0)),
                             keep_locked, locked('foo', '1.7.7'))
        versions(res).should == %w(2.0.0 1.8.0 1.7.8 1.7.9 1.7.7)

        # From right-to-left:
        # prefer the current version first (keep locked is true!)
        # prefer the most recent maj.min next
        # prefer remaining maj.min next
        # prefer minor increase next
        # prefer major increase last
      end

      it 'when unlocking favor next release, then current over minor increase' do
        res = @cr.sort_specs(create_specs('foo', %w(1.7.7 1.7.8 1.7.9 1.8.0)),
                             unlocking, locked('foo', '1.7.8'))
        versions(res).should == %w(1.8.0 1.7.8 1.7.9)
      end

      it 'leave current when unlocking but already at latest release' do
        res = @cr.sort_specs(create_specs('foo', %w(1.7.9 1.8.0 2.0.0)),
                             unlocking, locked('foo', '1.7.9'))
        versions(res).should == %w(2.0.0 1.8.0 1.7.9)
      end

      # patching (ab)uses overriding the locked_spec to push up gems needing patching, and otherwise
      # we don't want to jump up higher than what's needed, because the goal is not an overall jump
      # to latest release/minor, but to 'just get patched' and get on with it.
      #
      # TODO: that attitude ^^ is debatable. Patch plus latest release/minor could also be desired.
      it 'when unlocking and when patching order is strictly oldest to newest' do
        @cr.patching = true
        versions = %w(1.7.8 1.7.9 1.8.0 2.0.0 2.1.0 3.0.0 3.0.1 3.1.0 3.1.1 3.2.0)
        res = @cr.sort_specs(create_specs('foo', versions),
                             unlocking, locked('foo', '1.7.5'))
        versions(res).should == versions.reverse
      end

      # see prior spec comment explaining why the `unlocking_gem` value here makes no difference in patching cases.
      it 'when not unlocking and when patching order is also strictly oldest to newest' do
        @cr.patching = true
        versions = %w(1.7.8 1.7.9 1.8.0 2.0.0 2.1.0 3.0.0 3.0.1 3.1.0 3.1.1 3.2.0)
        res = @cr.sort_specs(create_specs('foo', versions),
                             keep_locked, locked('foo', '1.7.5'))
        versions(res).should == versions.reverse
      end
    end

    context 'sort specs (not strict) (minor allowed)' do
      it 'when unlocking favor next release, then minor increase over current' do
        @cr.minor_allowed = true
        res = @cr.sort_specs(create_specs('foo', %w(2.4.0 2.4.1 2.5.0)),
                             unlocking, locked('foo', '2.4.0'))
        versions(res).should == %w(2.4.0 2.4.1 2.5.0)
      end
    end
  end
end
