require_relative '../../spec_helper'

describe 'Bundler version installed' do
  it 'should be correct on Travis CI' do
    if ENV['TRAVIS'] && ENV['BUNDLER_TEST_VERSION'] != 'latest'
      Bundler::VERSION.should == ENV['BUNDLER_TEST_VERSION']
    end
  end
end
