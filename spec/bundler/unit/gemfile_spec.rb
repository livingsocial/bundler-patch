require_relative '../../spec_helper'

require 'fileutils'

RSpec::Matchers.define :have_line do |expected|
  match do |actual|
    actual.split(/\n/).map(&:strip).include?(expected)
  end
  failure_message do |actual|
    "expected line <#{expected}> would be in:\n#{actual}"
  end
end

describe Gemfile do
  before do
    @tmpdir = Dir.mktmpdir
  end

  after do
    FileUtils.remove_entry_secure @tmpdir
  end

  def dump
    puts "---Gemfile#{'-' * 80}"
    puts File.read('Gemfile')
    puts
    puts "---Gemfile.lock#{'-' * 75}"
    puts File.read('Gemfile.lock')
  end

  def gem_fixture_create(dir, gems, locks=nil)
    GemfileLockFixture.create(dir: dir, gems: gems, locks: locks) do |fix_dir|
      yield fix_dir
    end
  end

  describe 'Gemfile definition' do
    describe 'gem name matching' do
      it 'should not get confused by gems with same ending' do
        gem_fixture_create(@tmpdir, {rails: '3.2.2', :'jquery-rails' => '3.1.3'}) do
          s = Gemfile.new(gem_name: 'rails', patched_versions: ['3.2.22.2'])
          s.update
          File.read('Gemfile').should have_line("gem 'rails', '3.2.22.2'")
          File.read('Gemfile').should have_line("gem 'jquery-rails', '3.1.3'")
        end
      end
    end

    describe 'requirements cases' do
      # cases based on http://guides.rubygems.org/patterns/#pessimistic-version-constraint

      it 'should support no version' do
        gem_fixture_create(@tmpdir, {foo: nil}, {foo: '1.2.3'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.2.4'])
          s.update
          # TODO: consider 'fixing' to "gem 'foo', '>= 1.2.4'"
          File.read('Gemfile').should have_line("gem 'foo'")
          File.read('Gemfile.lock').should have_line('foo (1.2.3)') # not updating Gemfile.lock anymore
        end
      end

      it 'should support exact version' do
        gem_fixture_create(@tmpdir, {foo: '1.2.3'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.2.4'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '1.2.4'")
          File.read('Gemfile.lock').should have_line('foo (1.2.3)') # not updating Gemfile.lock anymore
        end
      end

      it 'should support exact version across major rev' do
        # TODO: major rev usually means breaking changes, so stay put. output warning?
        gem_fixture_create(@tmpdir, {foo: '1.2.3'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['2.0.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '1.2.3'")
          File.read('Gemfile.lock').should have_line('foo (1.2.3)')
        end
      end

      it 'should support greater than version' do
        gem_fixture_create(@tmpdir, {foo: '> 1.2'}, {foo: '1.2.5'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '>= 1.3.0'")
        end
      end

      it 'should support greater than or equal version' do
        gem_fixture_create(@tmpdir, {foo: '>=1.2'}, {foo: '1.2.5'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '>= 1.3.0'")
        end
      end

      it 'should support less than version when patched still less than spec' do
        gem_fixture_create(@tmpdir, {foo: '< 3'}, {foo: '2.4'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['2.5.1'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '< 3'")
        end
      end

      it 'should support less than version when patched greater than spec and across minor rev' do
        gem_fixture_create(@tmpdir, {foo: '< 2.6'}, {foo: '2.4'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['2.7.1'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 2.7'")
        end
      end

      it 'should support less than version when patched greater than spec and across major rev' do
        # TODO: major rev usually means breaking changes, so stay put. output warning?
        pending('this case will need some special handling')
        gem_fixture_create(@tmpdir, {foo: '< 3'}, {foo: '2.4'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['3.1.1'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '< 3'")
        end
      end

      it 'should support less than equal to version' do
        # `<=` operator isn't documented on the web, but it is supported in the code
        gem_fixture_create(@tmpdir, {foo: '<= 2.6'}, {foo: '2.4'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['2.7.1'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 2.7'")
        end
      end

      it 'should support twiddle-wakka with two segments' do
        gem_fixture_create(@tmpdir, {foo: '~>1.2'}, {foo: '1.2.5'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 1.3'")
        end
      end

      it 'should support twiddle-wakka with three segments' do
        gem_fixture_create(@tmpdir, {foo: '~>1.2.1'}, {foo: '1.2.5'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 1.3.0'")
        end
      end

      # long form is an equivalent twiddle-wakka
      it 'should support twiddle-wakka long form leaving existing if patch within existing requirement' do
        # equivalent to ~> 1.2.0
        gem_fixture_create(@tmpdir, {foo: ['>= 1.2.0', '< 1.3.0']}, {foo: '1.2.5'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.2.7'])
          s.update
          # TODO: this is inconsistent, should probably change to ~> 1.2.7. Other cases
          # change the Gemfile to ensure it won't ever load a lower one. ... Except
          # Bundler does take care of that doesn't it?
          #
          # But, the case of '>= 1.2.0', '< 1.4.2' -- would have to be changed to
          #                  '>= 1.2.7', '< 1.4.2'
          #
          # Compound forms aren't common, and supporting a more intelligent upgrade when the
          # patch is still inside the req is probably not worth the trouble.
          File.read('Gemfile').should have_line("gem 'foo', '< 1.3.0', '>= 1.2.0'")
        end
      end

      it 'should support twiddle-wakka long form replacing req if patch outside existing requirement' do
        # equivalent to ~> 1.2.0
        gem_fixture_create(@tmpdir, {foo: ['>= 1.2.0', '< 1.3.0']}, {foo: '1.2.5'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 1.3.0'")
        end
      end

      it 'should support compound with twiddle-wakka if patch inside existing req' do
        gem_fixture_create(@tmpdir, {foo: ['>= 1.2.1.2', '~> 1.2.1']}, {foo: '1.2.1.3'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.2.4'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '>= 1.2.1.2', '~> 1.2.1'")
        end
      end

      it 'should support compound with twiddle-wakka if patch outside existing req' do
        gem_fixture_create(@tmpdir, {foo: ['>= 1.2.1.2', '~> 1.2.1']}, {foo: '1.2.1.3'}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 1.3.0'")
        end
      end

      it 'should be okay with whitespace variations' do
        gem_fixture_create(@tmpdir, {:' foo ' => ' >   1.2 '}, {:' foo ' => ' 1.2.5    '}) do
          s = Gemfile.new(gem_name: 'foo', patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem ' foo ', '>= 1.3.0'")
        end
      end
    end

    describe 'Insecure sources' do
      it 'should support http to https'

      it 'should support git to https'

      it 'should support source standalone declaration'

      it 'should support source block'

      it 'should support source inline'
    end

    describe '.gemspec files' do
      it 'should support .gemspec files too'
    end

    describe 'update gemfile requirements' do
      it 'could have command to update all specific versions to twiddle-waka'

      it 'could have command to update all too-specific twiddle-waka to less specific'

      it 'could have command to update all greater than or equal to to twiddle-waka'
    end
  end
end


