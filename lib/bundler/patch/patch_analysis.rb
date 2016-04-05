module Bundler::Patch
  # TODO - kill. Not using.
  class PatchAnalysis
    def initialize(lockfile=nil)
      @lockfile = lockfile || Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock'))
    end

    def check_gem(gem_name, version)
      checking_gem = Gem::Specification.new(gem_name, version)
      conflicting_specs = []
      @lockfile.specs.each do |s|
        dep = s.dependencies.detect { |d| d.name == gem_name }
        conflicting_specs << s if dep unless dep =~ checking_gem
      end
      Result.new(patchable: conflicting_specs.empty?,
                 conflicting_specs: conflicting_specs)
    end

    class Result
      attr_reader :conflicting_specs

      def initialize(patchable:, conflicting_specs: [])
        @patchable = patchable
        @conflicting_specs = conflicting_specs
      end

      def patchable?
        @patchable
      end
    end
  end
end
