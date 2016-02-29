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
        file_replace do |match, re|
          operator_re = /([~<>=]+)/
          case match
          when operator_re
            just_version_re = /\d\S*\b/
            current_version = match.scan(just_version_re).join
            new_version = calc_new_version(current_version)

            contents_in_quotes = match.scan(/,.*['"](.*)['"]/).join
            new_version ? match.sub(contents_in_quotes, ">= #{new_version}") : match
          else
            update_to_new_version(match, re)
          end
        end
      end

      @target_file = 'Gemfile.lock'
      @gems.each do |gem|
        @regexes = /#{gem}.+\((.*)\)/
        file_replace
      end
    end
  end
end
