class TargetBundle
  attr_reader :dir, :gemfile

  def initialize(dir: Dir.pwd, gemfile: 'Gemfile')
    @dir = dir
    @gemfile = gemfile
  end
end
