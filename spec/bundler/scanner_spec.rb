require_relative '../spec_helper'

describe Scanner do
  before do
    @bf = BundlerFixture.new
  end

  after do
    @bf.clean_up
  end

  def test_conservative_update(gems_to_update, options, bundler_def)
    prep = DefinitionPrep.new(bundler_def, gems_to_update, options).tap { |p| p.prep }
    prep.bundler_def.lock(File.join(Dir.pwd, 'Gemfile.lock'))
  end

  context 'conservative update' do
    def setup_lockfile
      Dir.chdir(@bf.dir) do
        @bf.create_lockfile(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false)
        yield
      end
    end

    def lockfile_spec_version(gem_name)
      @bf.parsed_lockfile_spec(gem_name).version.to_s
    end

    it 'when updated gem has same dep req' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: true, minor_allowed: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'when updated gem has updated dep req increase major, strict and non-strict' do
      setup_lockfile do
        bundler_def = lambda { @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '~> 2.0']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '2.0.0'),
            @bf.create_spec('bar', '2.0.1'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo') }

        test_conservative_update('foo', {strict: true, minor_allowed: true}, bundler_def.call)
        lockfile_spec_version('foo').should == '2.4.0'

        test_conservative_update('foo', {strict: false, minor_allowed: true}, bundler_def.call)
        lockfile_spec_version('foo').should == '2.5.0'
      end
    end

    it 'when updated gem has updated dep req increase major, not strict' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '~> 2.0']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '2.0.0'),
            @bf.create_spec('bar', '2.0.1'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: false, minor_allowed: true}, bundler_def)

        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('bar').should == '2.0.1'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'updating multiple gems with same req' do
      setup_lockfile do
        gems_to_update = ['foo', 'quux']
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: gems_to_update)
        test_conservative_update(gems_to_update, {strict: true, minor_allowed: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.2.0'
      end
    end

    it 'updates all conservatively' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '1.1.4'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: true)
        test_conservative_update(true, {strict: true, minor_allowed: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.4'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.2.0'
      end
    end

    it 'updates all conservatively when no upgrade exists' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false, update_gems: true)
        test_conservative_update(true, {strict: true, minor_allowed: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.4.0'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    context 'no locked_spec exists' do
      def with_bundler_setup
        # bundler has special checks to not include itself in a lot of things
        Dir.chdir(@bf.dir) do
          @bf.create_lockfile(
            gem_dependencies: [@bf.create_dependency('foo')],
            source_specs: [
              @bf.create_spec('foo', '1.0.0', [['bundler', '>= 0']]),
              @bf.create_spec('bundler', '1.10.6'),
            ], ensure_sources: false)

          @bundler_def = @bf.create_definition(
            gem_dependencies: [@bf.create_dependency('foo')],
            source_specs: [
              @bf.create_spec('foo', '1.0.0', [['bundler', '>= 0']]),
              @bf.create_spec('foo', '1.0.1', [['bundler', '>= 0']]),
              @bf.create_spec('bundler', '1.10.6'),
            ], ensure_sources: false, update_gems: true)
          yield
        end
      end

      it 'does not explode when strict' do
        with_bundler_setup do
          test_conservative_update(true, {strict: true}, @bundler_def)
        end
      end

      it 'does not explode when not strict' do
        with_bundler_setup do
          test_conservative_update(true, {strict: false}, @bundler_def)
        end
      end
    end

    it 'should never increment major version' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '3.0.0', [['bar', '~> 2.0']]),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '2.0.0'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: true, minor_allowed: true}, bundler_def)

        lockfile_spec_version('foo').should == '2.4.0'
        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'strict mode should still go to the most recent release version' do
      setup_lockfile do
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.4.1', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.4.2', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('quux', '0.0.4'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict: true}, bundler_def)

        lockfile_spec_version('foo').should == '2.4.2'
        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'the caching caused the not-a-conflict job_board json conflict'

    it 'needs to pass-through all install or update bundler options'
    it 'needs to cope with frozen setting'
    # see bundler-1.10.6/lib/bundler/installer.rb comments for explanation of frozen

  end

  context 'spec processing' do
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
