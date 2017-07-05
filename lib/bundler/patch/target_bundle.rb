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
                 File.read('.ruby-version').chomp
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

  # Have to run a separate process in the other Ruby, because Bundler::Settings#path ultimately
  # arrives at RbConfig::CONFIG which is all special data derived from the active runtime.
  # TODO: fix ^^
  def gem_home
    cmd = "#{ruby_bin_exe} -C#{@dir} -e 'puts Gem.default_dir'"
    puts cmd if ENV['BP_DEBUG']
    path = `#{cmd}`.chomp
    expanded_path = Pathname.new(path).expand_path(@dir).to_s
    if ENV['BP_DEBUG']
      puts cmd
      puts path
      puts expanded_path
    end
    expanded_path
  end

  # To properly update another bundle, bundler-patch _does_ need to live in the same bundle
  # location because of its _dependencies_ (it's not a self-contained gem), and it can't both
  # act on another bundle location AND find its own dependencies in a separate bundle location.

  # TODO: gem_home for this purpose does not need to be the local bundle path, can just
  # be in the Ruby "global" gem home, right?
  def install_bundler_patch_in_target
    cmd = "#{ruby_bin}#{File::SEPARATOR}gem install -V --install-dir #{gem_home} --conservative --no-document --prerelease bundler-patch"
    puts cmd if ENV['BP_DEBUG']
    system cmd

    cmd = "ls #{ruby_bin}#{File::SEPARATOR}**"
    puts cmd if ENV['BP_DEBUG']
    system cmd
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
