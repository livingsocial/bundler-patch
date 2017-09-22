module Bundler::Patch
  class CLI
    class Options
      def normalize_options(options)
        map = {:prefer_minimal => :minimal, :strict_updates => :strict, :minor_preferred => :minor}
        {}.tap do |target|
          options.each_pair do |k, v|
            new_key = k.to_s.gsub('-', '_').to_sym
            new_key = map[new_key] || new_key
            target[new_key] ||= v
          end
          process_gemfile_option(target)
        end
      end

      private

      def process_gemfile_option(options)
        # copy/pasta from Bundler
        custom_gemfile = options[:gemfile] || Bundler.settings[:gemfile]
        if custom_gemfile && !custom_gemfile.empty?
          custom_gemfile = File.join(custom_gemfile, TargetBundle.default_gemfile) if File.directory?(custom_gemfile)
          ENV['BUNDLE_GEMFILE'] = File.expand_path(custom_gemfile)
          dir, gemfile = [File.dirname(custom_gemfile), File.basename(custom_gemfile)]
          target_bundle = TargetBundle.new(dir: dir, gemfile: gemfile)
          options[:target] = target_bundle
        else
          options[:target] = TargetBundle.new
        end
      end
    end
  end
end
