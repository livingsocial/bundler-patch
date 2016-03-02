require 'bundler/audit'
require 'bundler/audit/database'
require 'bundler/audit/scanner'
require 'boson/runner'

module Bundler::Patch
  # wraps Bundler::Audit::Scanner
  class Scanner < Boson::Runner
    def initialize
      @no_vulns_message = 'No known vulnerabilities to update.'
    end

    option :advisory_db_path, type: :string, desc: "Optional custom advisory db path. See #{Bundler::Audit::Database::URL} to emulate."
    desc 'Scans current directory for known vulnerabilities and outputs them.'

    def scan(options={})
      _scan(options)

      if @specs.empty? then
        puts @no_vulns_message
      else
        puts # extra line to separate from advisory db update text
        puts 'Detected vulnerabilities:'
        puts '-------------------------'
        puts @specs.map(&:to_s).join("\n")
      end
    end

    option :advisory_db_path, type: :string, desc: "Optional custom advisory db path. See #{Bundler::Audit::Database::URL} to emulate."
    desc 'Scans current directory for known vulnerabilities and attempts to patch your files to fix them.'

    def patch(options={})
      _scan(options)

      @specs.map(&:update)
      gems = @specs.map(&:gems).flatten
      if gems.empty?
        puts @no_vulns_message
      else
        cmd = "bundle update #{gems.uniq.join(' ')}"
        puts cmd
        system cmd
      end
    end

    private

    def _scan(options)
      Bundler::Audit::Database.update!
      @results = Bundler::Audit::Scanner.new.scan.to_a

      if options[:advisory_db_path]
        db = Bundler::Audit::Database.new(options[:advisory_db_path])
        scanner = Bundler::Audit::Scanner.new
        scanner.instance_variable_set('@database', db) # hack
        @results += scanner.scan.to_a
      end

      @specs = @results.map do |struct|
        case struct
        when Bundler::Audit::Scanner::UnpatchedGem
          patched = struct.advisory.patched_versions.map do |pv|
            pv.requirements.map { |_, v| v.to_s }
          end.flatten
          gem = struct.gem.name
          Gemfile.new(gems: [gem], patched_versions: patched)
        end
      end
    end
  end
end
