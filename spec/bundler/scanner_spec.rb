require_relative '../spec_helper'

describe Scanner do
  it 'should support custom database for internal gems'

  it 'should have existing stuff tested' # i should backfill some testing here eventually. first shot easy enough to 'test' manually

  it 'could re-detect unfixed stuff after bundle audit and notify'

  it 'could attempt to discover requirements that will not allow an upgrade'
  # e.g. if foo requires a specific version of bar that won't allow bar to be patched, then either notify or try
  # to bundle update foo as well. maybe support that as an aggressive option or somesuch.


  context 'conservative update' do
    before do
      @bf = BundlerFixture.new
    end

    after do
      @bf.clean_up
    end

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

    it 'when updated gem has same dep req' do
      setup_lockfile do
        scan = Bundler::Patch::Scanner.new
        def_builder = lambda { @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: 'foo'
        ) }
        scan.conservative_update('foo', def_builder)

        @bf.parsed_lockfile_spec('bar').version.to_s.should == '1.1.3'
        @bf.parsed_lockfile_spec('foo').version.to_s.should == '2.5.0'
        @bf.parsed_lockfile_spec('quux').version.to_s.should == '0.0.4'
      end
    end

    it 'when updated gem has updated dep req' do
      setup_lockfile do
        scan = Bundler::Patch::Scanner.new
        def_builder = lambda { @bf.create_definition(
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
          ], ensure_sources: false, update_gems: 'foo'
        ) }
        scan.conservative_update('foo', def_builder)

        # here's a case where it might be nice to just go to 2.0.1. Presuming SemVer (which is dangerous)
        # 2.0.1 has a bugfix that 2.0.0 doesn't, so ... why not just go to 2.0.1?
        @bf.parsed_lockfile_spec('bar').version.to_s.should == '2.0.0'
        @bf.parsed_lockfile_spec('foo').version.to_s.should == '2.5.0'
        @bf.parsed_lockfile_spec('quux').version.to_s.should == '0.0.4'
      end
    end

    it 'updating multiple gems with same req' do
      setup_lockfile do
        scan = Bundler::Patch::Scanner.new
        gems_to_update = ['foo', 'quux']
        def_builder = lambda { @bf.create_definition(
          gem_dependencies: [@bf.create_dependency('foo'), @bf.create_dependency('quux')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('foo', '2.5.0', [['bar', '>= 1.0.4']]),
            @bf.create_spec('bar', '1.1.2'),
            @bf.create_spec('bar', '1.1.3'),
            @bf.create_spec('bar', '3.2.0'),
            @bf.create_spec('quux', '0.2.0'),
          ], ensure_sources: false, update_gems: gems_to_update
        ) }
        scan.conservative_update(gems_to_update, def_builder)

        # here's a case where it might be nice to just go to 2.0.1. Presuming SemVer (which is dangerous)
        # 2.0.1 has a bugfix that 2.0.0 doesn't, so ... why not just go to 2.0.1?
        @bf.parsed_lockfile_spec('bar').version.to_s.should == '1.1.3'
        @bf.parsed_lockfile_spec('foo').version.to_s.should == '2.5.0'
        @bf.parsed_lockfile_spec('quux').version.to_s.should == '0.2.0'
      end
    end
  end
end

