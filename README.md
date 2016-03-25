# Bundler::Patch

`bundler-patch` can update your Gemfile conservatively to deal with vulnerable gems or just get more current.

## Goals

- Update the Gemfile, .ruby-version and other files to patch an app according to `ruby-advisory-db` content.
- Don't upgrade past the minimum gem version required.
- Minimal munging to existing version spec.
- Support a database of custom advisories for internal gems.

## Installation

    $ gem install bundler-patch

## Usage

### Scan / Patch Security Vulnerable Gems

To output the list of detected vulnerabilities in the current project:

    $ bundle-patch scan

To specify the path to an optional advisory database:

    $ bundle-patch scan -a ~/.my-custom-db

*NOTE*: `gems` will be appended to the end of the path.

To attempt to patch the detected vulnerabilities, use the `patch` command instead of `scan`:

    $ bundle-patch patch

Same options apply. Read the next section for details on how bumps to release, minor and major versions work.

For help:

    $ bundle-patch help scan
    $ bundle-patch help patch

### Conservatively Update All Gems

To update any gem conservatively, use the `update` command:

    $ bundle-patch update 'foo bar'

This will attempt to upgrade the `foo` and `bar` gems to the latest release version. (e.g. if the current version is
`1.4.3` and the latest available `1.4.x` version is `1.4.8`, it will attempt to upgrade it to `1.4.8`). If any
dependent gems need to be upgraded to a new minor or even major version, then it will do those as well, presuming the
gem requirements specified in the `Gemfile` also allow it.

If you want to restrict _any_ gem from being upgraded past the most recent release version, use `--strict` mode:

    $ bundle-patch update 'foo bar' --strict

This will eliminate any newer minor or major releases for any gem. If Bundler is unable to upgrade the requested gems
due to the limitations, it will leave the requested gems at their current version.

If you want to allow minor release upgrades (e.g. to allow an upgrade from `1.4.3` to `1.6.1`) use the `--minor_allowed`
option.

`--minor_allowed` (alias `-m`) and `--strict` (alias `-s`) can be used together or independently.

While `--minor_allowed` is most useful in combination with the `--strict` option, it can also influence behavior when
not in strict mode.

For example, if an update to `foo` is requested, current version is `1.4.3` and `foo` has both `1.4.8` and `1.6.1`
available, then without `--minor_allowed` and without `--strict`, `foo` itself will only be upgraded to `1.4.8`, though
any gems further down the dependency tree could be upgraded to a new minor or major version if they have to be to use
`foo 1.4.8`.

Continuing the example, _with_ `--minor_allowed` (but still without `--strict`) `foo` itself would be upgraded to
`1.6.1`, and as before any gems further down the dependency tree could be upgraded to a new minor or major version if
they have to.

To request conservative updates for the entire Gemfile, simply call `update`:

    $ bundle-patch update

There's no option to allow major version upgrades as this is the default behavior of `bundle update` in Bundler itself.


### Troubleshooting

All this tool does is output a `bundle update gem1 gem2 ...` command, so most problems with getting the update to work
are usual Bundler problems. Check for any dependencies that depend on a gem that needs to be updated and has a
constraining requirement that won't allow the newer gem.


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


