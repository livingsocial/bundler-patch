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
        puts "Updating '#{gems_to_update.join(" ")}' to address vulnerabilities"
        Bundler.ui = Bundler::UI::Shell.new
        Bundler::CLI::Update.new({}, gems_to_update).run
      end
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
