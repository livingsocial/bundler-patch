require 'bundler/audit/database'
require 'bundler/audit/scanner'

module Bundler::Patch
  # wraps Bundler::Audit::Scanner
  class Scanner
    def initialize
    end

    def scan
      Bundler::Audit::Database.update!
      @results = Bundler::Audit::Scanner.new.scan.to_a
      patch
    end

    def patch
      specs = @results.map do |struct|
        case struct
        when Bundler::Audit::Scanner::UnpatchedGem
          patched = struct.advisory.patched_versions.map { |pv| pv.requirements.map { |_, v| v.to_s } }.flatten
          gem = struct.gem.name
          Gemfile.new(gems: [gem], patched_versions: patched)
        end
      end

      specs.map(&:update)
      gems = specs.map(&:gems).flatten
      cmd = "bundle update #{gems.uniq.join(' ')}"
      puts cmd
      system cmd
    end
  end
end
