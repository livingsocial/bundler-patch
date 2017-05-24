class TargetBundle
  attr_reader :dir, :gemfile

  # TODO: Make gems.rb default in Bundler 2.0.
  def initialize(dir: Dir.pwd, gemfile: 'Gemfile', use_target_ruby: false)
    @dir = dir
    @gemfile = gemfile
    @use_target_ruby = use_target_ruby
  end

  # First, the version of Ruby itself:
  # 1. Look in the Gemfile for ruby version
  # 2. Look for a .ruby-version file
  # 3. (An additional flag so user can specify?)
  #
  # Second, look bin path presuming version is in current path.
  def find_target_ruby_version
    # TODO: LockfileParser didn't have this until 1.12
    Bundler::Definition.build(gemfile_name, lockfile_name, nil).ruby_version
    # Bundler::LockfileParser.new(File.join(@dir, "#{@gemfile}.lock")).ruby_version
  end

  def gemfile_name
    File.join(@dir, @gemfile)
  end

  def lockfile_name
    "#{gemfile_name}.lock"
  end

  def find_target_ruby_bin
    
  end

  def find_target_gem_home
    
  end

  # To properly update another bundle, bundler-patch _does_ need to live in the same bundle
  # location because of it's _dependencies_ (it's not a self-contained gem), and it can't both
  # act on another bundle location AND find its own dependencies in a separate bundle location.
  def install_bundler_patch_in_target
    
  end
end
