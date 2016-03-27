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

    def test_conservative_update(gems_to_update, options, bundler_def)
      prep = DefinitionPrep.new(bundler_def, gems_to_update, options).tap { |p| p.prep }
      prep.bundler_def.lock(File.join(Dir.pwd, 'Gemfile.lock'))
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

    it 'what happens when a new version introduces a brand new gem' #?
  end
end
