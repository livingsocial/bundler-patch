module Bundler::Patch
  class Gemfile < UpdateSpec
    def initialize(target_file: 'Gemfile',
                   target_dir: Dir.pwd,
                   regexes: [/.*/],
                   patched_versions: [])
      super(target_file: target_file,
            target_dir: target_dir,
            regexes: regexes,
            patched_versions: patched_versions)
    end
  end
end
