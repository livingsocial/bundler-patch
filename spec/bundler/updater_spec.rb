require_relative '../spec_helper'

require 'bundler/patch/updater'

require 'fileutils'

include Bundler::Patch

describe UpdateSpec do
  before do
    patched_versions = %w(1.9.3-p550 2.1.4 ruby-2.1.4-p265 jruby-1.7.16.1)
    @u = UpdateSpec.new.tap { |u| u.patched_versions = patched_versions }
  end

  it 'calc_new_version' do
    @u.calc_new_version('1.8').should == '1.9.3-p550'
    @u.calc_new_version('1.9').should == '1.9.3-p550'
    @u.calc_new_version('1.9.3-p484').should == '1.9.3-p550'
    @u.calc_new_version('2.0.0-p95').should == '2.1.4'
    @u.calc_new_version('2').should == '2.1.4'
    @u.calc_new_version('2.1.2').should == '2.1.4'
    @u.calc_new_version('2.1.2-p95').should == '2.1.4'
    @u.calc_new_version('jruby-1.7').should == 'jruby-1.7.16.1'
    @u.calc_new_version('jruby-1.6.5').should == 'jruby-1.7.16.1'
    @u.calc_new_version('1.7').should == '1.9.3-p550'
    @u.calc_new_version('ruby-2.1.2-p95').should == 'ruby-2.1.4-p265'
    @u.calc_new_version('ruby-2.1.2-p0').should == 'ruby-2.1.4-p265'
    @u.calc_new_version('ruby-2.1.2').should == 'ruby-2.1.4-p265'
  end
end

describe Updater do
  before do
    dirs = %w(./fixture/bar ./fixture/foo ./fixture/java)
    old = %w(1.9.3-p484 2.1.2 ruby-2.1.2-p95 jruby-1.7.16)
    patched_versions = %w(1.9.3-p550 2.1.4 ruby-2.1.4-p265 jruby-1.7.16.1)

    specs = dirs.map do |d|
      UpdateSpec.new.tap do |s|
        s.target_file = '.ruby-version'
        s.patched_versions = patched_versions
      end
    end

    @u = Updater.new(specs)

    dirs.each_with_index do |dir, i|
      dir = File.join(File.dirname(__FILE__), dir)
      FileUtils.makedirs dir
      fn = File.join(dir, '.ruby-version')
      File.open(fn, 'w') { |f| f.puts old[i] }
    end
  end

  after do
    FileUtils.rmtree(File.join(File.dirname(__FILE__), 'fixture'))
  end

  it 'should support ensure_clean_git option' # just need tests around this

  it 'should support custom file replacement definitions'

  it 'should support Gemfile replacements' # existing ruby version replacement code didn't do Gemfile yet

  it 'should use definition mechanism internally'
end
