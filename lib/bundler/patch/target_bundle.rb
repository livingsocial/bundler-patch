class TargetBundle
  attr_reader :dir, :gemfile

  # TODO: support gems.rb in Bundler 2.0
  def initialize(dir: Dir.pwd, gemfile: 'Gemfile')
    @dir = dir
    @gemfile = gemfile
  end
end
