module Bundler::Patch
  class UpdateSpec
    attr_accessor :target_file, :target_dir, :patched_versions

    def initialize
      @target_file = 'Gemfile'
      @target_dir = Dir.pwd
      @target_path_fn = File.join(@target_dir, @target_file)
      @patched_versions = []
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
        begin
          prep_git_checkout(spec) if options[:ensure_clean_git]

          # this should be refactored so there's simply a list of
          update_ruby_version(spec)
          update_jenkins_versions(spec)

          # this is LS specific, we should support custom replacements
          update_manifest(spec)
        rescue => e
          puts "#{spec[:project]}: #{e.message}"
        end
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

    def update_ruby_version(spec)
      ruby_version_filename = File.join(spec.target_dir, '.ruby-version')
      file_replace(ruby_version_filename, /.*/)
    end

    def update_manifest(spec)
      manifest = File.join(spec.target_dir, 'manifest.yml')
      file_replace(manifest, [/runtime: (.*)/])
    end

    def update_jenkins_versions(spec)
      jenkins_filename = File.join(spec.target_dir, '.jenkins.xml')
      file_replace(jenkins_filename, [/\<string\>(.*)\<\/string\>/,
                                      /rvm.*\>ruby-(.*)@/,
                                      /version.*rbenv.*\>(.*)\</])
    end

    def file_replace(filename, res)
      unless File.exist?(filename)
        verbose_puts "Cannot find #{filename}"
        return
      end

      lines = File.readlines(filename)
      any_changes = false
      lines.map! do |ln|
        re = [res].flatten.detect { |re| !ln.scan(re).empty? }
        app_version = re ? ln.scan(re).join : nil
        if app_version.nil?
          ln
        else
          new_version = calc_new_version(app_version)
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

