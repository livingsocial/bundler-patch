require_relative '../../spec_helper'

describe 'Bundler version installed' do
  it 'should be correct' do
    puts `gem list bundler`
    puts `bundle env`
    Bundler::VERSION.should == ENV['BUNDLER_TEST_VERSION']
  end
end
