require_relative '../spec_helper'

describe Scanner do
  before do
    @bf = BundlerFixture.new
  end

  after do
    @bf.clean_up
  end

  context 'patch analysis' do
    def setup_lockfile
      Dir.chdir(@bf.dir) do
        @bf.create_lockfile(
          gem_dependencies: [@bf.create_dependency('foo')],
          source_specs: [
            @bf.create_spec('foo', '2.4.0', [['bar', '~> 1.0']]),
            @bf.create_spec('bar', '1.2.0')
          ],
          ensure_sources: false)
        yield
      end
    end

    it 'should pass when parent req will not allow' do
      setup_lockfile do
        PatchAnalysis.new.check_gem('bar', '1.3.1').tap do |res|
          res.patchable?.should == true
          res.conflicting_specs.length.should == 0
        end
      end
    end

    it 'should fail when parent req will not allow' do
      setup_lockfile do
        PatchAnalysis.new.check_gem('bar', '2.0.0').tap do |res|
          res.patchable?.should == false
          res.conflicting_specs.map { |s| [s.name, s.version.to_s] }.flatten.should == %w(foo 2.4.0)
        end
      end
    end
  end
end
