module Bundler::Patch
  class RubyVersion < UpdateSpec
    RUBY_VERSION_LINE_REGEXPS = [/ruby\s+["'](.*)['"]/]

    def self.files
      @files ||= {
        '.ruby-version' => [/.*/]
      }
    end

    def initialize(target_bundle: TargetBundle.new, patched_versions: [])
      super(target_file: target_bundle.gemfile,
            target_dir: target_bundle.dir,
            regexes: regexes,
            patched_versions: patched_versions)
    end

    def update
      hash = self.class.files.dup
      hash[@target_file.dup] = RUBY_VERSION_LINE_REGEXPS
      hash.each_pair do |file, regexes|
        @target_file = file
        @regexes = regexes
        file_replace
      end
    end
  end
end
