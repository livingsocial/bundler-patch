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

    def to_s
      "#{@gems.join} #{patched_versions}"
    end

    def update
      # Bundler evals the whole Gemfile in Bundler::Dsl.evaluate
      # It has a few magics to parse all possible calls to `gem`
      # command. It doesn't have anything to output the entire
      # Gemfile, I don't think it ever does that. (There is code
      # to init a Gemfile from a gemspec, but it doesn't look
      # like it's intended to recreate one just evaled - I don't
      # see any code that would handle additional sources or
      # groups - see lib/bundler/rubygems_ext.rb #to_gemfile).
      #
      # So without something in Bundler that round-trips from
      # Gemfile back to disk and maintains integrity, then we
      # couldn't re-use it to make modifications to the Gemfile
      # like we'd want to, so we'll do this ourselves.
      #
      # We'll still instance_eval the gem line though, to properly
      # handle the various options and possible multiple reqs.
      @target_file = 'Gemfile'
      @gems.each do |gem|
        @regexes = /^\s*gem.*$/
        file_replace do |match, re|
          dep = instance_eval(match)
          new_prefix = case dep.requirement.requirements.first.first
                       when '>', '>='
                         '>= '
                       when '<', '<=', '~>'
                         '~> '
                       else
                         ''
                       end
          update_to_new_gem_version(match, dep, new_prefix)
        end
      end
    end

    def update_to_new_gem_version(match, dep, prefix)
      current_version = dep.requirement.requirements.first.last.to_s
      new_version = calc_new_version(current_version)

      if new_version && prefix =~ /~/
        # match segments
        count = current_version.split(/\./).length
        new_version = new_version.split(/\./)[0..(count-1)].join('.')
      end

      # TODO: this isn't going to hold up with multiple requirements
      #       or complicated gem commands with options and all
      contents_in_quotes = match.scan(/,.*['"](.*)['"]/).join
      if new_version
        match.sub(contents_in_quotes, "#{prefix}#{new_version}").tap { |s| "Updating to #{s}" }
      else
        match
      end
    end

    private

    # See Bundler::Dsl for reference
    def gem(name, *args)
      # we're not concerned with options here.
      _options = args.last.is_a?(Hash) ? args.pop.dup : {}
      version = args || ['>= 0']

      # there is a normalize_options step that DOES involve
      # the args captured in version for `git` and `path`
      # sources that's skipped here ... need to dig into that
      # at some point.

      Gem::Dependency.new(name, version)
    end
  end
end
