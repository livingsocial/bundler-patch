require_relative '../spec_helper'

require 'fileutils'

describe UpdateSpec do
  before do
    patched_versions = %w(1.9.3-p550 2.1.4 ruby-2.1.4-p265 jruby-1.7.16.1)
    @u = UpdateSpec.new(patched_versions: patched_versions)
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
