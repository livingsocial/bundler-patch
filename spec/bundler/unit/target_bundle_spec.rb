require_relative '../../spec_helper'

describe TargetBundle do
  it 'should default to current directory and Gemfile' do
    TargetBundle.new.tap do |bnd|
      bnd.dir.should == Dir.pwd
      bnd.gemfile.should == 'Gemfile'
    end
  end
end
