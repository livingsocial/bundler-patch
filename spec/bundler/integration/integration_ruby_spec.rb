# TODO: merge this with integration_spec once bundler 1.13 branch is merged
require_relative '../../spec_helper'

class BundlerFixture
  def gemfile_filename
    File.join(@dir, 'Gemfile')
  end

  def gemfile_contents
    File.read(gemfile_filename)
  end
end

describe CLI do
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

  context 'integration tests' do
    context 'ruby patch' do
      it 'update mri ruby' do
        Dir.chdir(@bf.dir) do
          File.open('Gemfile', 'w') { |f| f.puts "ruby '2.1.5'"}
          CLI.new.patch(ruby: true, rubies: ['2.1.6'])
          File.read('Gemfile').chomp.should == "ruby '2.1.6'"
        end
      end
    end
  end
end
