require 'rspec/core/rake_task'

task :default => :unit
task :test => 'test:unit'

namespace :test do
  desc 'Run all RSpec code examples'
  RSpec::Core::RakeTask.new(:all)

  desc 'Run RSpec unit code examples'
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = 'spec/bundler/unit/**{,/*/**}/*_spec.rb'
  end

  desc 'Run RSpec integration code examples'
  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = 'spec/bundler/integration/**{,/*/**}/*_spec.rb'
  end
end

require 'bundler/gem_tasks'

