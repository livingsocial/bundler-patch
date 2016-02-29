module Bundler::Patch
  class Gemfile < UpdateSpec
    attr_reader :gems # TODO: this will like never be used as an array, right?

    def initialize(target_dir: Dir.pwd,
                   gems: [],
                   patched_versions: [])
      super(target_file: 'Gemfile',
            target_dir: target_dir,
            patched_versions: patched_versions)
      # TODO: support Gem::Requirement in patched_versions
      @gems = gems
    end

    def update
      # should we be jacking around with this ourselves, or using Bundler code?
      # see -> Gem::Requirement for some help most likely.
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
      if new_version
        match.sub(contents_in_quotes, "#{prefix} #{new_version}").tap { |s| "Updating to #{s}" }
      else
        match
      end
    end
  end
end
