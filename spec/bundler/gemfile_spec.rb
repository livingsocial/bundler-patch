require_relative '../spec_helper'

require 'fileutils'

class GemfileLockFixture
  def self.create(dir, gems={})
    fix = self.new(dir, gems).tap do |fix|
      fix.create_gemfile
      fix.create_gemfile_lock
    end
    if block_given?
      Dir.chdir fix.dir do
        yield fix.dir
      end
    end
  end

  def self.create_with_content(dir, content)
    fix = self.new(dir, []).tap do |fix|
      fix.create_gemfile_content(content)
    end
    if block_given?
      Dir.chdir fix.dir do
        yield fix.dir
      end
    end
  end

  attr_reader :dir, :gems

  def initialize(dir, gems)
    @dir = dir
    @gems = gems
  end

  def create_gemfile
    lines = []
    lines << "source 'https://rubygems.org'"
    @gems.each do |name, version|
      lines << "gem '#{name}', '#{version}'"
    end
    write_lines(lines, 'Gemfile')
    File.join(@dir, 'Gemfile')
  end

  def create_gemfile_content(content)
    # split newline is dorky, but hey
    write_lines(content.split("\n"), 'Gemfile')
  end

  def create_gemfile_lock
    lines = []
    lines << 'GEM'
    lines << '  remote: https://rubygems.org/'
    lines << '  specs:'
    @gems.each do |name, version|
      lines << "    #{name} (#{version})"
    end
    lines << ''
    lines << 'PLATFORMS'
    lines << '  ruby'
    lines << ''
    lines << 'DEPENDENCIES'
    @gems.each do |name, version|
      lines << "  #{name}!"
    end
    lines
    write_lines(lines, 'Gemfile.lock')
    File.join(@dir, 'Gemfile.lock')
  end

  def write_lines(lines, filename)
    File.open(File.join(@dir, filename), 'w') { |f| f.puts lines }
  end
end


describe Gemfile do
  describe 'Gemfile definition' do
    before do
      @tmpdir = Dir.mktmpdir
    end

    after do
      FileUtils.remove_entry_secure @tmpdir
    end

    def dump
      puts '*' * 80
      puts File.read('Gemfile')
      puts '*' * 80
      puts File.read('Gemfile.lock')
    end

    # cases based on http://guides.rubygems.org/patterns/#pessimistic-version-constraint

    it 'should support no version'

    it 'should support exact version' do
      GemfileLockFixture.create(@tmpdir, {foo: '1.2.3'}) do
        s = Gemfile.new(target_dir: Dir.pwd, gems: ['foo'], patched_versions: ['1.2.4'])
        s.update
        File.read('Gemfile').split(/\n/)[-1].should == "gem 'foo', '1.2.4'"
      end
    end

    it 'should support greater than version'

    it 'should support greater than or equal version'

    it 'should support twiddle-wakka'

    it 'should support twiddle-wakka long form'

    it 'should support twiddle-wakka compound form'
  end

  describe 'Gemfile.lock only' do

  end

  describe 'Insecure sources' do
    it 'should support http to https'

    it 'should support git to https'

    it 'should support source standalone declaration'

    it 'should support source block'

    it 'should support source inline'
  end
end


