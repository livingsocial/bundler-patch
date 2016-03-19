require 'bundler/advise'
require 'boson/runner'

module Bundler::Patch
  class Scanner < Boson::Runner
    def initialize
      @no_vulns_message = 'No known vulnerabilities to update.'
    end

    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
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

    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    desc 'Scans current directory for known vulnerabilities and attempts to patch your files to fix them.'

    def patch(options={})
      _scan(options)

      @specs.map(&:update)
      gems = @specs.map(&:gems).flatten
      if gems.empty?
        puts @no_vulns_message
      else
        gems_to_update = gems.uniq
        conservative_update(gems_to_update)
      end
    end

    def conservative_update(gems_to_update, def_builder=lambda { Bundler.definition({gems: gems_to_update}) })
      gems_to_update = Array(gems_to_update)
      puts "Updating '#{gems_to_update.join(' ')}' to address vulnerabilities"
      bundler_def = def_builder.call
      bundler_def.extend ConservativeDefinition
      bundler_def.gems_to_update = gems_to_update
      bundler_def.lock(File.join(Dir.pwd, 'Gemfile.lock'))
    end

    private

    def _scan(options)
      Bundler::Advise::Advisories.new.tap do |ads|
        ads.update
        @results = Bundler::Advise::GemAdviser.new(advisories: ads).scan_lockfile
      end

      if options[:advisory_db_path]
        ads = Bundler::Advise::Advisories.new(dir: options[:advisory_db_path])
        @results += Bundler::Advise::GemAdviser.new(advisories: ads).scan_lockfile
      end

      @specs = @results.map do |advisory|
        patched = advisory.patched_versions.map do |pv|
          pv.requirements.map { |_, v| v.to_s }
        end.flatten
        gem = advisory.gem
        Gemfile.new(gems: [gem], patched_versions: patched)
      end
    end
  end
end

module ConservativeResolver
  def locked_specs=(value)
    @locked_specs = value
  end

  def unlock=(value)
    @unlock = value
  end

  def conservative_search_for
    @conservative_search_for ||= {}
  end

  def search_for(dependency)
    res = super(dependency)

    dep = dependency.dep unless dependency.is_a? Gem::Dependency
    conservative_search_for[dep] ||= begin
      res.select! do |sg|
        # filter out old versions so we don't regress
        # if the gem is unlocked, then filter out current and older versions.
        # if the gem is locked, then filter out only older versions.

        # SpecGroup is grouped by name/version, multiple entries for multiple platforms.
        # We only need the name, which will be the same, so hard coding to first is ok.
        gem_spec = sg.first
        op = @unlock.include?(gem_spec.name) ? :> : :>=

        # an Array per version returned, different entries for different platforms.
        # We just need the version here so it's ok to hard code this to the first instance.
        locked_spec = @locked_specs[gem_spec.name].first
        gem_spec.version.send(op, locked_spec.version)
      end

      # hand the resolution engine versions in older to newer order, rather than the default recent to older order.
      res.reverse
    end
  end
end

module Bundler::Patch
  module ConservativeDefinition
    def gems_to_update=(value)
      # @unlock has this value in the initializer, but gets eager_loaded
      # by the end of it, and won't serve the purpose this module needs.
      @gems_to_update = value
    end

    # This copies way too much code, but for now is an acceptable step forward. Intervening into the creation
    # of a Definition instance is a bit of a pain, a lot of preliminary data has to be gathered first, and
    # copying this one method, avoids copying much of that code.
    def resolve
      @resolve ||= begin
        last_resolve = converge_locked_specs
        if Bundler.settings[:frozen] || (!@unlocking && nothing_changed?)
          last_resolve
        else
          # Run a resolve against the locally available gems
          base = last_resolve.is_a?(Bundler::SpecSet) ? Bundler::SpecSet.new(last_resolve) : []
          resolver = Bundler::Resolver.new(index, source_requirements, base)
          resolver.extend ConservativeResolver
          resolver.locked_specs = @locked_specs
          resolver.unlock = @gems_to_update
          result = resolver.start(expanded_dependencies)
          spec_set = Bundler::SpecSet.new(result)

          last_resolve.merge spec_set
        end
      end
    end
  end
end
