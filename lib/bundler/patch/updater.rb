module Bundler::Patch
  class UpdateSpec
    attr_accessor :target_file, :target_dir, :regexes, :patched_versions

    def initialize(target_file: '',
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

    def calc_new_version(old_version)
      old = old_version
      all = @patched_versions.dup
      return old_version if all.include?(old)

      all << old
      all.sort!
      all.delete_if { |v| v.split(/\./).first != old.split(/\./).first } # strip non-matching major revs
      res = all[all.index(old) + 1]
      res ? res.to_s : nil
    end

    def file_replace
      filename = target_path_fn
      unless File.exist?(filename)
        puts "Cannot find #{filename}"
        return
      end

      guts = File.read(filename)
      any_changes = false
      [@regexes].flatten.each do |re|
        any_changes = guts.gsub!(re) do |match|
          if block_given?
            yield match, re
          else
            update_to_new_version(match, re)
          end
        end || any_changes
      end

      if any_changes
        File.open(filename, 'w') { |f| f.print guts }
        verbose_puts "Updated #{filename}"
      else
        verbose_puts "No changes for #{filename}"
      end
    end

    def update_to_new_version(match, re)
      current_version = match.scan(re).join
      new_version = calc_new_version(current_version)
      new_version ? match.sub(current_version, new_version) : match
    end

    alias_method :update, :file_replace

    def verbose_puts(text)
      puts text if @verbose
    end
  end
end

# def prep_git_checkout(spec)
#   Dir.chdir(spec.target_dir) do
#     status_first_line = `git status`.split("\n").first
#     raise "Not on master: #{status_first_line}" unless status_first_line == '# On branch master'
#
#     raise 'Uncommitted files' unless `git status --porcelain`.chomp.empty?
#
#     verbose_puts `git pull`
#   end
# end

