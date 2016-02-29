module Bundler::Patch
  class Gemfile < UpdateSpec
    # One file needs updating, with a specific gem.
    def initialize(target_dir: Dir.pwd,
                   gems: [],
                   patched_versions: [])
      super(target_file: 'Gemfile',
            target_dir: target_dir,
            patched_versions: patched_versions)
      @gems = gems
    end

    def update
      @gems.each do |gem|
        @regexes = /gem.+#{gem}.+['"](.*)['"]/
        file_replace
      end
    end
  end
end
