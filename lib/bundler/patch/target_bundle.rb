class TargetBundle
  attr_reader :dir, :gemfile

  def self.bundler_version_or_higher(version)
    version_greater_than_or_equal_to_other(Bundler::VERSION, version)
  end

  def self.version_greater_than_or_equal_to_other(a, b)
    Gem::Version.new(a) >= Gem::Version.new(b)
  end

  # TODO: Make gems.rb default in Bundler 2.0.
  def initialize(dir: Dir.pwd, gemfile: 'Gemfile')
    @dir = dir
    @gemfile = gemfile
  end

  # First, the version of Ruby itself:
  # 1. Look in the Gemfile/lockfile for ruby version
  # 2. Look for a .ruby-version file
  # 3. (An additional flag so user can specify?)
  #
  # Second, look bin path presuming version is in current path.
  def ruby_version
    result = if TargetBundle.bundler_version_or_higher('1.12.0') && File.exist?(lockfile_name)
               lockfile_parser = Bundler::LockfileParser.new(Bundler.read_file(lockfile_name))
               lockfile_parser.ruby_version
             end

    result ||= if File.exist?(ruby_version_filename)
                 File.read(File.join(@dir, '.ruby-version')).chomp
               else
                 Bundler::Definition.build(gemfile_name, lockfile_name, nil).ruby_version
               end

    version, patch_level = result.to_s.scan(/(\d+\.\d+\.\d+)(p\d+)*/).first
    patch_level ? "#{version}-#{patch_level}" : version
  end

  # This is hairy here. All the possible variants will make this mucky, but ... can
  # prolly get close enough in many circumstances.
  def ruby_bin(current_ruby_bin=RbConfig::CONFIG['bindir'], target_ruby_version=self.ruby_version)
    [
      target_ruby_version,
      target_ruby_version.gsub(/-p\d+/, ''),
      "ruby-#{target_ruby_version}",
      "ruby-#{target_ruby_version.gsub(/-p\d+/, '')}"
    ].map do |ruby_ver|
      build_ruby_bin(current_ruby_bin, ruby_ver)
    end.detect do |ruby_ver|
      print "Looking for #{ruby_ver}... " if ENV['BP_DEBUG']
      File.exist?(ruby_ver).tap { |exist| puts(exist ? 'found' : 'not found') if ENV['BP_DEBUG'] }
    end
  end

  def build_ruby_bin(current_ruby_bin, target_ruby_version)
    current_ruby_bin.split(File::SEPARATOR).reverse.map do |segment|
      if segment =~ /\d+\.\d+\.\d+/
        segment.gsub(/(\d+\.\d+\.\d+)-*(p\d+)*/, target_ruby_version)
      else
        segment
      end
    end.reverse.join(File::SEPARATOR)
  end

  def ruby_bin_exe
    File.join(ruby_bin, "#{RbConfig::CONFIG['ruby_install_name']}#{RbConfig::CONFIG['EXEEXT']}")
  end

  # Have to run a separate process in the other Ruby, because Gem.default_dir depends on
  # RbConfig::CONFIG which is all special data derived from the active runtime. It could perhaps
  # be redone here, but I'd rather not copy that code in here at the moment.
  #
  # At one point during development, this would execute Bundler::Settings#path, which in most
  # cases would just fall through to Gem.default_dir ... but would give preference to GEM_HOME
  # env variable, which could be in a different Ruby, and that won't work.
  def gem_home
    result = shell_command "#{ruby_bin_exe} -C#{@dir} -e 'puts Gem.default_dir'"
    path = result[:stdout].chomp
    expanded_path = Pathname.new(path).expand_path(@dir).to_s
    puts expanded_path if ENV['BP_DEBUG']
    expanded_path
  end

  # To properly update another bundle, bundler-patch _does_ need to live in the same Ruby 
  # version because of its _dependencies_ (it's not a self-contained gem), and it can't both
  # act on another bundle location AND find its own dependencies in a separate bundle location.
  #
  # One known issue: older RubyGems in older Rubies don't install bundler-patch bin in the right
  # directory. Upgrading RubyGems fixes this.
  def install_bundler_patch_in_target
    # TODO: reconsider --conservative flag. Had problems with it in place on Travis, but I think I want it.
    # cmd = "#{ruby_bin}#{File::SEPARATOR}gem install -V --install-dir #{gem_home} --conservative --no-document --prerelease bundler-patch"
    cmd = "#{ruby_bin}#{File::SEPARATOR}gem install -V --install-dir #{gem_home} --no-document --prerelease bundler-patch"
    shell_command cmd
  end

  private

  def ruby_version_filename
    File.join(@dir, '.ruby-version')
  end

  def gemfile_name
    File.join(@dir, @gemfile)
  end

  def lockfile_name
    "#{gemfile_name}.lock"
  end
end
