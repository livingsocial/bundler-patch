class TargetBundle
  attr_reader :dir, :gemfile

  def self.bundler_version_or_higher(version)
    Gem::Version.new(Bundler::VERSION) >= Gem::Version.new(version)
  end

  # TODO: Make gems.rb default in Bundler 2.0.
  def initialize(dir: Dir.pwd, gemfile: 'Gemfile', use_target_ruby: false)
    @dir = dir
    @gemfile = gemfile
    @use_target_ruby = use_target_ruby
  end

  # First, the version of Ruby itself:
  # 1. Look in the Gemfile/lockfile for ruby version
  # 2. Look for a .ruby-version file
  # 3. (An additional flag so user can specify?)
  #
  # Second, look bin path presuming version is in current path.
  def find_target_ruby_version
    # TODO: if directly provided (via command line switch?)
    result = if TargetBundle.bundler_version_or_higher('1.12.0')
               lockfile_parser = Bundler::LockfileParser.new(Bundler.read_file(lockfile_name))
               lockfile_parser.ruby_version
             end

    result ||= if File.exist?(ruby_version_filename)
                 File.read('.ruby-version').chomp
               else
                 Bundler::Definition.build(gemfile_name, lockfile_name, nil).ruby_version
               end

    result
  end

  def ruby_version_filename
    File.join(@dir, '.ruby-version')
  end

  def gemfile_name
    File.join(@dir, @gemfile)
  end

  def lockfile_name
    "#{gemfile_name}.lock"
  end

  def find_target_ruby_bin
    # RbConfig::CONFIG['bindir']
  end

  def find_target_gem_home

  end

  # To properly update another bundle, bundler-patch _does_ need to live in the same bundle
  # location because of it's _dependencies_ (it's not a self-contained gem), and it can't both
  # act on another bundle location AND find its own dependencies in a separate bundle location.
  def install_bundler_patch_in_target

  end
end
