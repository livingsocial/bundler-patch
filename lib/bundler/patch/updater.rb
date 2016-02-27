module Bundler::Patch
  class UpdateSpec
    attr_accessor :target_file, :target_dir, :regexes, :patched_versions

    def initialize(target_file: 'Gemfile',
                   target_dir: Dir.pwd,
                   regexes: [/.*/],
                   patched_versions: [])
      @target_file = target_file
      @target_dir = target_dir
      @regexes = regexes
      @patched_versions = patched_versions
    end

    def target_path_fn
      File.join(@target_dir, @target_file)
    end

    # this would prolly be educational to play ruby golf with.
    def calc_new_version(old_version)
      re_bit = /\d+/
      segments = 3
      until segments == 0 do
        matches = @patched_versions.select do |v|
          re = ".*?#{([re_bit] * segments).join('\.')}"
          a, b = [v.scan(/#{re}/).compact.flatten.first, old_version.scan(/#{re}/).compact.flatten.first]
          !a.nil? && (a == b)
        end
        # final or clause here is a total hack
        return matches.first if matches.length == 1 || (matches.length > 0 && segments == 1)
        segments -= 1
      end
      nil
    end
  end

  class Updater
    attr_accessor :verbose

    def initialize(update_specs=[], options={})
      @update_specs = update_specs
      @options = options
    end

    def update_apps
      @update_specs.each do |spec|
        prep_git_checkout(spec) if @options[:ensure_clean_git]

        file_replace(spec)
      end
    end

    def prep_git_checkout(spec)
      Dir.chdir(spec.target_dir) do
        status_first_line = `git status`.split("\n").first
        raise "Not on master: #{status_first_line}" unless status_first_line == '# On branch master'

        raise 'Uncommitted files' unless `git status --porcelain`.chomp.empty?

        verbose_puts `git pull`
      end
    end

    def file_replace(spec)
      # SMELL: spec envy
      filename = spec.target_path_fn
      unless File.exist?(filename)
        puts "Cannot find #{filename}"
        return
      end

      lines = File.readlines(filename)
      any_changes = false
      lines.map! do |ln|
        re = [spec.regexes].flatten.detect { |re| !ln.scan(re).empty? }
        app_version = re ? ln.scan(re).join : nil
        if app_version.nil?
          ln
        else
          new_version = spec.calc_new_version(app_version)
          if app_version == new_version
            ln
          else
            p({filename: filename, app_version: app_version, new_version: new_version}) if @verbose
            raise "Nil new_version for #{app_version}" if new_version.nil?
            any_changes = true
            ln.sub(app_version, new_version)
          end
        end
      end
      if any_changes
        File.open(filename, 'w') { |f| f.puts lines }
        verbose_puts "Updated #{filename}"
      else
        verbose_puts "No changes for #{filename}"
      end
    end

    def verbose_puts(text)
      puts text if @verbose
    end
  end
end

