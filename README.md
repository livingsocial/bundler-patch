# Bundler::Patch

`bundler-audit` has all the information one needs to patch your Gemfile for you. And while this should still require
your brain, there's some busy work here the monster inside your computer could assist you with.

## Goals

- Update the Gemfile, .ruby-version and other files to patch an app according to bundler-audit results.
- Don't upgrade past the minimum gem version required.
- Minimal munging to existing version spec.
- Support a database of custom advisories for internal gems.

## Installation

    $ gem install bundler-patch

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/livingsocial/bundler-patch.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


## Misc

None of these do what we need, but may have some code doing some similar work in places.

- http://www.rubydoc.info/gems/bundler-auto-update/0.1.0 (runs tests after each gem upgrade)
- http://www.rubydoc.info/gems/bundler-updater/0.0.3 (interactive prompt for what's available to upgrade to)
- https://github.com/rosylilly/bundler-add (outputs Gemfile line for adding a gem)


