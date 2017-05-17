module Bundler::Patch
  class RubyVersion < UpdateSpec
    RUBY_VERSION_LINE_REGEXPS = [/ruby\s+["'](.*)['"]/]

    def self.files
      @files ||= {
        '.ruby-version' => [/.*/],
        'Gemfile' => RUBY_VERSION_LINE_REGEXPS,
        'gems.rb' => RUBY_VERSION_LINE_REGEXPS,
      }
    end

    def initialize(target_bundle: TargetBundle.new, patched_versions: [])
      super(target_file: target_bundle.gemfile,
            target_dir: target_bundle.dir,
            regexes: regexes,
            patched_versions: patched_versions)
    end

    def update
      self.class.files.each_pair do |file, regexes|
        @target_file = file
        @regexes = regexes
        file_replace
      end
    end
  end
end
