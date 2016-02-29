module Bundler::Patch
  class Gemfile < UpdateSpec
    def initialize(target_dir: Dir.pwd,
                   gems: [],
                   patched_versions: [])
      super(target_file: 'Gemfile',
            target_dir: target_dir,
            patched_versions: patched_versions)
      @gems = gems
    end

    def update
      @target_file = 'Gemfile'
      @gems.each do |gem|
        @regexes = /gem.+#{gem}.+['"](.*)['"]/
        file_replace
      end

      @target_file = 'Gemfile.lock'
      @gems.each do |gem|
        @regexes = /#{gem}.+\((.*)\)/
        file_replace
      end
    end
  end
end
