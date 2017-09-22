require_relative '../../spec_helper'

describe Bundler::Patch::CLI::Options do
  context 'normalize_options' do
    def normalized_should_eql(actual, expected)
      actual = actual.delete_if { |k, _| k == :target }
      actual.should == expected
    end

    it 'should support hyphen and underscore options equally' do
      opts = {:'hyphen-ated' => 1, 'string' => 1, :symbol => 1, :under_score => 1}
      norm = Bundler::Patch::CLI::Options.new.normalize_options(opts)
      normalized_should_eql(norm, {:hyphen_ated => 1, :string => 1, :symbol => 1, :under_score => 1})
    end

    it 'should not blow away an earlier setting' do
      opts = {:'a-b' => 1, :a_b => nil}
      norm = Bundler::Patch::CLI::Options.new.normalize_options(opts)
      normalized_should_eql(norm, {:a_b => 1})
    end

    it 'should map old names to new names' do
      opts = {:prefer_minimal => true, :minor_preferred => true, :strict_updates => true}
      norm = Bundler::Patch::CLI::Options.new.normalize_options(opts)
      normalized_should_eql(norm, {:minimal => true, :minor => true, :strict => true})
    end
  end

  context 'target bundle' do
    before do
      @tmp_dir = File.join(__dir__, 'fixture')
      FileUtils.makedirs @tmp_dir
    end

    after do
      FileUtils.rmtree(@tmp_dir)
    end

    it 'should detect having a directory passed and compensate with default Gemfile name' do
      bf = BundlerFixture.new(dir: @tmp_dir)
      bf.create_gemfile(gem_dependencies: bf.create_dependency('rack', '~> 1.0'))

      opts = {:gemfile => @tmp_dir}
      norm = Bundler::Patch::CLI::Options.new.normalize_options(opts)
      norm[:target].dir.should == @tmp_dir
      norm[:target].gemfile.should == 'Gemfile'
    end
  end
end
