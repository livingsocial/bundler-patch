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
          current_version = match.scan(re).join
          new_version = calc_new_version(current_version)
          new_version ? match.sub(current_version, new_version) : match
        end || any_changes
      end

      if any_changes
        File.open(filename, 'w') { |f| f.print guts }
        verbose_puts "Updated #{filename}"
      else
        verbose_puts "No changes for #{filename}"
      end
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

