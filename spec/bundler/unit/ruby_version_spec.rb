require_relative '../../spec_helper'

describe RubyVersion do
  before do
    setup_subject
  end

  after do
    FileUtils.rmtree(File.join(__dir__, 'fixture'))
  end

  def patched_versions
    %w(1.9.3-p550 2.1.4 ruby-2.1.4-p265 jruby-1.7.16.1)
  end

  def setup_subject
    dirs = %w(./fixture/1_9 ./fixture/2_1 ./fixture/java_1_7)
    old = %w(1.9.3-p484 2.1.2 jruby-1.7.16)

    @specs = dirs.map do |dir|
      %w(Gemfile gems.rb).map do |gemfile|
        target_bundle = TargetBundle.new(dir: File.join(__dir__, dir), gemfile: gemfile)
        Bundler::Patch::RubyVersion.new(target_bundle: target_bundle, patched_versions: patched_versions)
      end
    end.flatten

    dirs.each_with_index do |dir, i|
      dir = File.join(File.dirname(__FILE__), dir)
      FileUtils.makedirs dir
      fn = File.join(dir, '.ruby-version')
      File.open(fn, 'w') { |f| f.puts old[i] }

      File.open(File.join(dir, 'Gemfile'), 'w') { |f| f.puts "ruby '#{old[i]}'" }
      File.open(File.join(dir, 'gems.rb'), 'w') { |f| f.puts "ruby '#{old[i]}'" }
    end
  end

  it 'these tests are too confusing now' do
    fail
  end

  it 'should update ruby version files in different dirs' do
    @specs.map(&:update)

    read_spec_contents(@specs[0], '.ruby-version').should == '1.9.3-p550'
    read_spec_contents(@specs[2], '.ruby-version').should == '2.1.4'
    read_spec_contents(@specs[4], '.ruby-version').should == 'jruby-1.7.16.1'
  end

  it 'should update Gemfile' do
    @specs.map(&:update)

    read_spec_contents(@specs[0], 'Gemfile').should == "ruby '1.9.3-p550'"
    read_spec_contents(@specs[2], 'Gemfile').should == "ruby '2.1.4'"
    read_spec_contents(@specs[4], 'Gemfile').should == "ruby 'jruby-1.7.16.1'"
  end

  it 'should update gems.rb' do
    @specs.map(&:update)

    read_spec_contents(@specs[1], 'gems.rb').should == "ruby '1.9.3-p550'"
    read_spec_contents(@specs[3], 'gems.rb').should == "ruby '2.1.4'"
    read_spec_contents(@specs[5], 'gems.rb').should == "ruby 'jruby-1.7.16.1'"
  end

  def read_spec_contents(spec, filename)
    File.read(File.join(spec.target_dir, filename)).chomp
  end

  it 'should support custom file replacement definitions' do
    Bundler::Patch::RubyVersion.files['foo'] = 'bar'
    Bundler::Patch::RubyVersion.files['foo'].should == 'bar'
  end

  it 'should not blow up if no new version is found - dump warning?'
end
