# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bundler/patch/version'

Gem::Specification.new do |spec|
  spec.name          = 'bundler-patch'
  spec.version       = Bundler::Patch::VERSION
  spec.authors       = ['chrismo']
  spec.email         = ['chrismo@clabs.org']

  spec.summary       = %q{Patch Gemfile with bundler-audit results}
  # spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = 'https://github.com/livingsocial/bundler-patch'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://gems.livingsocial.net'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = ['bundle-patch']
  spec.require_paths = ['lib']

  spec.add_dependency 'bundler-audit'
  spec.add_dependency 'boson'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'ls-gem_tasks'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
end
