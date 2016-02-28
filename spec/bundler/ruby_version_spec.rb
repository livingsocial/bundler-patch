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

    @u = Updater.new(@specs)

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

  it 'should update ruby version files in different dirs' do
    @u.update_apps

    read_spec_contents(@specs[0]).should == '1.9.3-p550'
    read_spec_contents(@specs[1]).should == '2.1.4'
    read_spec_contents(@specs[2]).should == 'jruby-1.7.16.1'
  end

  def read_spec_contents(spec)
    File.read(spec.target_path_fn).chomp
  end

  it 'should support ensure_clean_git option' # just need tests around this

  it 'should support custom file replacement definitions'

  it 'should support Gemfile replacements' # existing ruby version replacement code didn't do Gemfile yet
end
