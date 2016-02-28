require_relative '../spec_helper'

describe RubyVersion do
  before do
    dirs = %w(./fixture/bar ./fixture/foo ./fixture/java)
    old = %w(1.9.3-p484 2.1.2 jruby-1.7.16)
    patched_versions = %w(1.9.3-p550 2.1.4 ruby-2.1.4-p265 jruby-1.7.16.1)

    @specs = dirs.map do |dir|
      Bundler::Patch::RubyVersion.new(target_dir: File.join(File.dirname(__FILE__), dir),
                                      patched_versions: patched_versions)
    end

    dirs.each_with_index do |dir, i|
      dir = File.join(File.dirname(__FILE__), dir)
      FileUtils.makedirs dir
      fn = File.join(dir, '.ruby-version')
      File.open(fn, 'w') { |f| f.puts old[i] }

      FileUtils.cp File.expand_path('../../fixture/.jenkins.xml', __FILE__), dir
    end
  end

  after do
    FileUtils.rmtree(File.join(File.dirname(__FILE__), 'fixture'))
  end

  it 'should update ruby version files in different dirs' do
    @specs.map(&:update)

    read_spec_contents(@specs[0], '.ruby-version').should == '1.9.3-p550'
    read_spec_contents(@specs[1], '.ruby-version').should == '2.1.4'
    read_spec_contents(@specs[2], '.ruby-version').should == 'jruby-1.7.16.1'
  end

  it 'should update .jenkins.xml file' do
    @specs.map(&:update)

    read_spec_contents(@specs[0], '.jenkins.xml').should match /1.9.3-p550/
    read_spec_contents(@specs[1], '.jenkins.xml').should match /2.1.4/
    read_spec_contents(@specs[2], '.jenkins.xml').should match /jruby-1.7.16.1/
  end

  def read_spec_contents(spec, filename)
    File.read(File.join(spec.target_dir, filename)).chomp
  end

  it 'should support ensure_clean_git option' # just need tests around this

  it 'should support custom file replacement definitions'

  # move to Gemfile spec
  it 'should support Gemfile replacements'

  it 'should not blow up if no new version is found - dump warning?'
end
