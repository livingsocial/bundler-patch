require_relative '../../spec_helper'

describe ConservativeDefinition do
  before do
    @bf = BundlerFixture.new
    ENV['BUNDLE_GEMFILE'] = File.join(@bf.dir, 'Gemfile')
  end

  after do
    ENV['BUNDLE_GEMFILE'] = nil
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
      gem_patches = Array(gems_to_update).map do |gem_name|
        gem_name.is_a?(String) ? GemPatch.new(gem_name: gem_name) : gem_name
      end
      prep = DefinitionPrep.new(bundler_def, gem_patches, options).tap { |p| p.prep }
      prep.bundler_def.tap { |bd| bd.lock(File.join(Dir.pwd, 'Gemfile.lock')) }
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
        test_conservative_update('foo', {strict_updates: true, minor_allowed: true}, bundler_def)

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

        test_conservative_update('foo', {strict_updates: true, minor_allowed: true}, bundler_def.call)
        lockfile_spec_version('foo').should == '2.4.0'

        test_conservative_update('foo', {strict_updates: false, minor_allowed: true}, bundler_def.call)
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
            @bf.create_specs('bar', %w(1.1.2 1.1.3 2.0.0 2.0.1 3.2.0)),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo')
        test_conservative_update('foo', {strict_updates: false, minor_allowed: true}, bundler_def)

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
        test_conservative_update(gems_to_update, {strict_updates: true, minor_allowed: true}, bundler_def)

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
        test_conservative_update([], {strict_updates: true, minor_allowed: true}, bundler_def)

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
        test_conservative_update([], {strict_updates: true, minor_allowed: true}, bundler_def)

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
          test_conservative_update([], {strict_updates: true}, @bundler_def)
        end
      end

      it 'does not explode when not strict' do
        with_bundler_setup do
          test_conservative_update([], {strict_updates: false}, @bundler_def)
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
        test_conservative_update('foo', {strict_updates: true, minor_allowed: true}, bundler_def)

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
        test_conservative_update('foo', {strict_updates: true}, bundler_def)

        lockfile_spec_version('foo').should == '2.4.2'
        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('quux').should == '0.0.4'
      end
    end

    it 'passing major increment in new_version in gems_to_update will not force a gem it' do
      setup_lockfile do
        gems_to_update = [GemPatch.new(gem_name: 'foo'), GemPatch.new(gem_name: 'quux', new_version: '2.4.0')]
        bundler_def = @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_specs('bar', %w(1.1.2 1.1.3 3.2.0)),
            @bf.create_specs('quux', %w(0.0.4 0.2.0 2.4.0)),
          ], ensure_sources: false, update_gems: %w(foo quux))
        test_conservative_update(gems_to_update, {strict_updates: false, minor_allowed: true}, bundler_def)

        lockfile_spec_version('bar').should == '1.1.3'
        lockfile_spec_version('foo').should == '2.5.0'
        lockfile_spec_version('quux').should == '0.2.0'
      end
    end

    it 'fixes up empty remotes in rubygems_aggregator' do
      # this test doesn't fail without the fixup code, but I already
      # commented I don't know the underlying cause, so better than nothing.
      gemfile = File.join(@bf.dir, 'Gemfile')
      File.open(gemfile, 'w') { |f| f.puts "source 'https://rubygems.org'" }
      setup_lockfile do
        bundler_def = test_conservative_update([], {strict_updates: false}, nil)
        sources = bundler_def.send(:sources)
        sources.rubygems_remotes.length.should_not == 0
      end
    end

    it 'should spec out prefer_minimal'

    it 'needs to pass-through all install or update bundler options' #?

    it 'needs to cope with frozen setting'
    # see bundler-1.10.6/lib/bundler/installer.rb comments for explanation of frozen

    it 'what happens when a new version introduces a brand new gem' #?
  end
end
