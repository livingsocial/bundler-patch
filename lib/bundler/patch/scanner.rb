require 'bundler/advise'
require 'boson/runner'

module Bundler::Patch
  class Scanner < Boson::Runner
    def initialize
      @no_vulns_message = 'No known vulnerabilities to update.'
    end

    option :advisory_db_path, type: :string, desc: 'Optional custom advisory db path.'
    desc 'Scans current directory for known vulnerabilities and outputs them.'

    def scan(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
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

    def patch(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      _scan(options)

      @specs.map(&:update)
      gems = @specs.map(&:gems).flatten
      if gems.empty?
        puts @no_vulns_message
      else
        gems_to_update = gems.uniq
        puts "Updating '#{gems_to_update.join(' ')}' to address vulnerabilities"
        conservative_update(gems_to_update)
      end
    end

    desc 'Conservatively updates all gems in the Gemfile based on current requirements.'

    option :strict, type: :boolean, desc: 'Remove undesired gem versions from index search results, causing dependency resolution to fail if conservative update cannot be accomplished.'
    option :minor_allowed, type: :boolean, desc: 'By default, only the most recent release version of the current major.minor will be updated to. Set this option to allow upgrading to the most recent minor.release of the current major version.'

    def update(options={}) # TODO: Revamp the commands now that we've broadened into security specific and generic
      conservative_update(true, options)
    end

    def conservative_update(gems_to_update, options={}, builder_def=nil)
      gems_to_update = Array(gems_to_update)

      Bundler.ui = Bundler::UI::Shell.new

      resolve_remote = false
      bundler_def = builder_def || begin
        unlock = (gems_to_update === [true]) ? true : {gems: gems_to_update}
        resolve_remote = true
        Bundler.definition(unlock)
      end
      bundler_def.extend ConservativeDefinition
      bundler_def.gems_to_update = gems_to_update
      bundler_def.strict = options[:strict]
      bundler_def.minor_allowed = options[:minor_allowed]
      bundler_def.resolve_remotely! if resolve_remote
      bundler_def.lock(File.join(Dir.pwd, 'Gemfile.lock'))
    end

    private

    def _scan(options)
      Bundler::Advise::Advisories.new.tap do |ads|
        ads.update
        @results = Bundler::Advise::GemAdviser.new(advisories: ads).scan_lockfile
      end

      # TODO: this bit of duplication is a little stupid
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

class ConservativeResolver < Bundler::Resolver
  attr_accessor :locked_specs, :unlock, :unlocking_all, :strict, :minor_allowed

  def search_for(dependency)
    res = super(dependency)

    dep = dependency.dep unless dependency.is_a? Gem::Dependency
    @conservative_search_for ||= {}
    #@conservative_search_for[dep] ||= # TODO turning off caching allowed a real-world sample to work, dunno why yet.
    begin
      gem_name = dep.name

      # if we're unlocking, we need to look for a newer one first, but fallback
      # to current version.
      unlocking_gem = (@unlocking_all || @unlock.include?(gem_name))

      # an Array per version returned, different entries for different platforms.
      # We just need the version here so it's ok to hard code this to the first instance.
      locked_spec = @locked_specs[gem_name].first

      (@strict ?
        filter_specs(res, unlocking_gem, locked_spec) :
        sort_specs(res, unlocking_gem, locked_spec)).tap do |res|
        if ENV['DEBUG_RESOLVER']
          # TODO: if we keep this, gotta go through Bundler.ui
          if res
            p [gem_name, res.map { |sg| [sg.version, sg.dependencies_for_activated_platforms.map { |dp| [dp.name, dp.requirement.to_s] }] }]
          else
            p "No res for #{gem_name}. Orig res: #{super(dependency)}"
          end
        end
      end
    end
  end

  def filter_specs(specs, unlocking_gem, locked_spec)
    ops = unlocking_gem ? [:>, :>=] : [:>=]

    res = ops.map do |op|
      specs.select do |sg|
        # SpecGroup is grouped by name/version, multiple entries for multiple platforms.
        # We only need the name, which will be the same, so hard coding to first is ok.
        gem_spec = sg.first

        if locked_spec
          gsv = gem_spec.version
          lsv = locked_spec.version

          must_match = @minor_allowed ? [0] : [0, 1]

          matches = must_match.map { |idx| gsv.segments[idx] == lsv.segments[idx] }
          (matches.uniq == [true]) ? gsv.send(op, lsv) : false
        else
          true
        end
      end
    end.detect { |a| !a.empty? }

    # hand the resolution engine versions in older to newer order, rather than the default recent to older order.
    res ? res.reverse : []
  end

  def sort_specs(specs, unlocking_gem, locked_spec)
    return specs unless locked_spec
    locked_version = locked_spec.version
    locked_spec_group = specs.detect { |s| s.first.version == locked_version }

    filtered = specs.select { |s| s.first.version >= locked_version }

    filtered.sort do |a, b|
      a_ver = a.first.version
      b_ver = b.first.version
      case
      when a_ver.segments[0] != b_ver.segments[0]
        b_ver <=> a_ver
      when !@minor_allowed && (a_ver.segments[1] != b_ver.segments[1])
        b_ver <=> a_ver
      else
        a_ver <=> b_ver
      end
    end.tap do |result|
      unless unlocking_gem
        # make sure the current locked version is last in list.
        result.reject! { |s| s.first.version === locked_version }
        result << locked_spec_group
      end
    end
  end
end

module Bundler::Patch
  module ConservativeDefinition
    # @unlock holds these in the initializer, but it gets eager_loaded
    # by the end of it, and won't serve the purpose this module needs.
    attr_accessor :gems_to_update

    # pass-through options to ConservativeResolver
    attr_accessor :strict, :minor_allowed

    # This copies way too much code, but for now is an acceptable step forward. Intervening into the creation
    # of a Definition instance is a bit of a pain, a lot of preliminary data has to be gathered first, and
    # copying this one method, avoids copying much of that code. Pick your poison.
    def resolve
      @resolve ||= begin
        last_resolve = converge_locked_specs
        if Bundler.settings[:frozen] || (!@unlocking && nothing_changed?)
          last_resolve
        else
          # Run a resolve against the locally available gems
          base = last_resolve.is_a?(Bundler::SpecSet) ? Bundler::SpecSet.new(last_resolve) : []
          resolver = ConservativeResolver.new(index, source_requirements, base)
          locked_specs = if @unlocking && @locked_specs.length == 0
                           # Have to grab these again. Default behavior is to not store any
                           # locked_specs if updating all gems, because behavior is the same
                           # with no lockfile OR lockfile but update them all. In our case,
                           # we need to know the locked versions for conservative comparison.
                           locked = Bundler::LockfileParser.new(@lockfile_contents)
                           resolver.unlocking_all = true
                           Bundler::SpecSet.new(locked.specs)
                         else
                           resolver.unlocking_all = false
                           @locked_specs
                         end
          resolver.locked_specs = locked_specs
          resolver.unlock = @gems_to_update
          resolver.strict = @strict
          resolver.minor_allowed = @minor_allowed
          result = resolver.start(expanded_dependencies)
          spec_set = Bundler::SpecSet.new(result)

          last_resolve.merge spec_set
        end
      end
    end
  end
end
