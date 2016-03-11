require_relative '../spec_helper'

require 'fileutils'

class GemfileLockFixture
  def self.create(dir, gems={}, locks=nil)
    fix = self.new(dir, gems, locks).tap do |fix|
      fix.create_gemfile
      fix.create_gemfile_lock
    end
    if block_given?
      Dir.chdir fix.dir do
        yield fix.dir
      end
    end
  end

  attr_reader :dir, :gems, :locks

  def initialize(dir, gems, locks=nil)
    @dir = dir
    @gems = gems
    @locks = locks
  end

  def create_gemfile
    lines = []
    lines << "source 'https://rubygems.org'"
    @gems.each do |name, version|
      line = "gem '#{name}'"
      line << ", '#{version}'" if version
      lines << line
    end
    write_lines(lines, 'Gemfile')
    File.join(@dir, 'Gemfile')
  end

  def create_gemfile_lock
    bf = BundlerFixture.new(dir: @dir)
    specs = (@locks || @gems).map { |name, version| bf.create_spec(name.to_s, version) }
    bf.create_lockfile(gem_specs: specs)
  end

  def write_lines(lines, filename)
    File.open(File.join(@dir, filename), 'w') { |f| f.puts lines }
  end
end

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

  describe 'Gemfile definition' do
    describe 'gem name matching' do
      it 'should not get confused by gems with same ending' do
        GemfileLockFixture.create(@tmpdir, {rails: '3.2.2', 'jquery-rails': '3.1.3'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['rails'], patched_versions: ['3.2.22.2'])
          s.update
          # TODO: consider 'fixing' to "gem 'foo', '>= 1.2.4'"
          File.read('Gemfile').should have_line("gem 'rails', '3.2.22.2'")
          File.read('Gemfile').should have_line("gem 'jquery-rails', '3.1.3'")
        end
      end
    end

    describe 'requirements cases' do
      # cases based on http://guides.rubygems.org/patterns/#pessimistic-version-constraint

      it 'should support no version' do
        GemfileLockFixture.create(@tmpdir, {foo: nil}, {foo: '1.2.3'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['1.2.4'])
          s.update
          # TODO: consider 'fixing' to "gem 'foo', '>= 1.2.4'"
          File.read('Gemfile').should have_line("gem 'foo'")
          File.read('Gemfile.lock').should have_line('foo (1.2.3)') # not updating Gemfile.lock anymore
        end
      end

      it 'should support exact version' do
        GemfileLockFixture.create(@tmpdir, {foo: '1.2.3'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['1.2.4'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '1.2.4'")
          File.read('Gemfile.lock').should have_line('foo (1.2.3)') # not updating Gemfile.lock anymore
        end
      end

      it 'should support exact version across major rev' do
        # TODO: major rev usually means breaking changes, so stay put. output warning?
        GemfileLockFixture.create(@tmpdir, {foo: '1.2.3'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['2.0.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '1.2.3'")
          File.read('Gemfile.lock').should have_line('foo (1.2.3)')
        end
      end

      it 'should support greater than version' do
        GemfileLockFixture.create(@tmpdir, {foo: '> 1.2'}, {foo: '1.2.5'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '>= 1.3.0'")
        end
      end

      it 'should support greater than or equal version' do
        GemfileLockFixture.create(@tmpdir, {foo: '>=1.2'}, {foo: '1.2.5'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '>= 1.3.0'")
        end
      end

      it 'should support less than version when patched still less than spec' do
        GemfileLockFixture.create(@tmpdir, {foo: '< 3'}, {foo: '2.4'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['2.5.1'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '< 3'")
        end
      end

      it 'should support less than version when patched greater than spec and across minor rev' do
        GemfileLockFixture.create(@tmpdir, {foo: '< 2.6'}, {foo: '2.4'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['2.7.1'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 2.7'")
        end
      end

      it 'should support less than version when patched greater than spec and across major rev' do
        # TODO: major rev usually means breaking changes, so stay put. output warning?
        pending('this case will need some special handling')
        GemfileLockFixture.create(@tmpdir, {foo: '< 3'}, {foo: '2.4'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['3.1.1'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '< 3'")
        end
      end

      it 'should support less than equal to version' # illegal? not documented

      it 'should support twiddle-wakka with two segments' do
        GemfileLockFixture.create(@tmpdir, {foo: '~>1.2'}, {foo: '1.2.5'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 1.3'")
        end
      end

      it 'should support twiddle-wakka with three segments' do
        GemfileLockFixture.create(@tmpdir, {foo: '~>1.2.1'}, {foo: '1.2.5'}) do
          s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['1.3.0'])
          s.update
          File.read('Gemfile').should have_line("gem 'foo', '~> 1.3.0'")
        end
      end

      it 'should support twiddle-wakka long form'

      it 'should support twiddle-wakka compound form'

      it 'should be okay with whitespace variations'
      # various forms here, dunno what's legal?
      # gem '  foo ', '  >=  1.4    '
      # gem '  foo ', '>=1.4'
      # gem 'foo','>=1.2'
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
  end
end


