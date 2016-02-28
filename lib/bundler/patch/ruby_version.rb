module Bundler::Patch
  class RubyVersion < UpdateSpec
    def self.files
      {
        '.ruby-version' => [/.*/],
        '.jenkins.xml' => [/\<string\>(.*)\<\/string\>/, /rvm.*\>ruby-(.*)@/, /version.*rbenv.*\>(.*)\</]
      }
    end

    def initialize(target_dir: Dir.pwd, patched_versions: [])
      super(target_file: target_file,
            target_dir: target_dir,
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
