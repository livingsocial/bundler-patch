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
      # should we be jacking around with this ourselves, or using Bundler code?
      @target_file = 'Gemfile'
      @gems.each do |gem|
        @regexes = /gem.+#{gem}.+['"](.*)['"]/
        file_replace do |match, re|
          case match
          when /[^~]>/
            update_to_new_pessimistic_version(match, '>=')
          when /</, /~>/
            update_to_new_pessimistic_version(match, '~>')
          else
            update_to_new_version(match, re)
          end
        end
      end

      # should we be jacking around with this ourselves, or using Bundler code?
      @target_file = 'Gemfile.lock'
      @gems.each do |gem|
        @regexes = /#{gem}.+\((.*)\)/
        file_replace
      end
    end

    def update_to_new_pessimistic_version(match, prefix)
      just_version_re = /\d\S*\b/
      current_version = match.scan(just_version_re).join
      new_version = calc_new_version(current_version)

      if new_version && prefix =~ /~/
        # match segments
        count = current_version.split(/\./).length
        new_version = new_version.split(/\./)[0..(count-1)].join('.')
      end

      contents_in_quotes = match.scan(/,.*['"](.*)['"]/).join
      new_version ? match.sub(contents_in_quotes, "#{prefix} #{new_version}") : match
    end
  end
end
