require_relative '../../spec_helper'

describe Bundler::Patch::CLI do
  it 'should support hyphen and underscore options equally' do
    cli = Bundler::Patch::CLI.new
    opts = {:'hyphen-ated' => 1, 'string' => 1, :symbol => 1, :under_score => 1}
    norm = cli.normalize_options(opts)
    norm.should == {:hyphen_ated => 1, :string => 1, :symbol => 1, :under_score => 1}
  end

  it 'should map old names to new names' do
    cli = Bundler::Patch::CLI.new
    opts = {:prefer_minimal => true, :minor_preferred => true, :strict_updates => true}
    norm = cli.normalize_options(opts)
    norm.should == {:minimal => true, :minor => true, :strict => true}
  end
end

