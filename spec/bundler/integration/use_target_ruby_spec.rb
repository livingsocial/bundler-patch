require_relative '../../spec_helper'

require 'tmpdir'

describe 'integration tests' do
  before do
    @tmp_dir = File.expand_path('../../../tmp', __dir__)
  end

  after do
    FileUtils.remove_entry_secure(@tmp_dir) if File.exist?(@tmp_dir)
  end

  def gemfile_create(ruby_version)
    GemfileLockFixture.create(dir: @tmp_dir, ruby_version: ruby_version) do |fix_dir|
      yield fix_dir
    end
  end

  context 'use target ruby' do
    it 'with same ruby no bundle config' do
      bf = GemfileLockFixture.create(dir: @tmp_dir,
                                     gems: {rack: nil, addressable: nil},
                                     locks: {rack: '1.4.1', addressable: '2.1.1'},
                                     ruby_version: RbConfig::CONFIG['RUBY_PROGRAM_VERSION'])

      with_clean_env do
        bundler_patch(gems_to_update: ['rack'],
                      gemfile: File.join(@tmp_dir, 'Gemfile'),
                      use_target_ruby: true)
      end

      bf.lockfile_spec_version('rack').should == '1.4.7'
      bf.lockfile_spec_version('addressable').should == '2.1.1'
    end

    it 'with different ruby no bundle config' do
      # Only the Gemfile is created here, with no lock file, because it won't work
      # in the fixture code to do the lock command against a declared older Ruby.
      #
      # The referenced Ruby version must be an installed version in the OS.
      glf = GemfileLockFixture.new(dir: @tmp_dir,
                                   gems: {rack: '~> 1.4.1', addressable: '2.1.1'},
                                   ruby_version: '2.4.5')
      glf.create_gemfile
      bf = glf.bundler_fixture

      output = nil
      with_clean_env do
        # Enable BP_DEBUG to troubleshoot the output
        output = bundler_patch(gems_to_update: ['rack'],
                               gemfile: File.join(@tmp_dir, 'Gemfile'),
                               use_target_ruby: true)
      end

      bf.lockfile_spec_version('rack').should == '1.4.7'
      bf.lockfile_spec_version('addressable').should == '2.1.1'

      output.should match /rack 1\.4\.7/
      output.should match /addressable 2\.1\.1/
    end

    it 'with different ruby bundle config install path' do
      # Only the Gemfile is created here, with no lock file, because it won't work
      # in the fixture code to do the lock command against a declared older Ruby.
      #
      # The referenced Ruby version must be an installed version in the OS.
      glf = GemfileLockFixture.new(dir: @tmp_dir,
                                   gems: {rack: '~> 1.4.1', addressable: '2.1.1'},
                                   ruby_version: '2.4.5')
      glf.create_gemfile
      bf = glf.bundler_fixture
      bf.create_config(path: 'local-path')

      output = nil
      with_clean_env do
        # Enable BP_DEBUG to troubleshoot the output
        output = bundler_patch(gems_to_update: ['rack'],
                               gemfile: File.join(@tmp_dir, 'Gemfile'),
                               use_target_ruby: true)
      end

      bf.lockfile_spec_version('rack').should == '1.4.7'
      bf.lockfile_spec_version('addressable').should == '2.1.1'

      output.should match /rack 1\.4\.7/
      output.should match /addressable 2\.1\.1/
    end
  end
end
