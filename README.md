# bundler-patch

`bundler-patch` can update your gems conservatively to deal with vulnerable
gems or just get more current.

By default, "conservatively" means it will prefer the latest patch releases
from the current version, over the latest minor releases or the latest major
releases. This is somewhat opposite from `bundle update` which prefers
newest/major versions first.

Works with Bundler 1.9 and higher. Starting with Bundler 1.13, much of the
core behavior in `bundler-patch` has been ported to Bundler itself. Read 
[BUNDLER.md](BUNDLER.md) for more information.

[![Build Status](https://travis-ci.org/livingsocial/bundler-patch.svg?branch=master)](https://travis-ci.org/livingsocial/bundler-patch)

## Installation

    $ gem install bundler-patch

## Usage

With the `bundler-patch` binary available, both `bundler-patch` and `bundle
patch` can be used to execute.

Without any options, all gems will be conservatively updated. An attempt to
upgrade any vulnerable gem (according to
https://github.com/rubysec/ruby-advisory-db) to a patched version will be
made.

    $ bundle patch

"Conservatively" means it will sort all available versions to prefer the latest
patch releases from the current version, then the latest minor releases and
then the latest major releases.

"Prefer" means that no available versions are removed from consideration*, to
help ensure a suitable dependency graph can be reconciled. This does mean some
gems cannot be upgraded or may be upgraded to unexpected versions. NOTE: There
is a `--strict_updates` option which _will_ remove versions from consideration,
see below.

_*That's a white-lie. bundler-patch will actually remove from consideration
any versions older than the currently locked version, which `bundle update`
will not do. It's not common, but it is possible for `bundle update` to
regress a gem to an older version, if necessary to reconcile the dependency
graph._

Gem requirements as defined in the Gemfile will still define what versions are
available. The new conservative behavior controls the preference order of those
versions.

For example, if gem 'foo' is locked at 1.0.2, with no gem requirement defined
in the Gemfile, and versions 1.0.3, 1.0.4, 1.1.0, 1.1.1, 2.0.0 all exist, the
default order of preference will be "1.0.4, 1.0.3, 1.0.2, 1.1.1, 1.1.0,
2.0.0".

In the same example, if gem 'foo' has a requirement of '~> 1.0', version 2.0.0
will be removed from consideration as always.

With no gem names provided on the command line, all gems will be unlocked and
open for updating. A list of gem names can be passed to restrict to just those
gems.

    $ bundle patch foo bar

  * `-m/--minor-preferred` option will give preference for minor versions over
    patch versions.

  * `-p/--prefer-minimal` option will reverse the preference order within
    patch, minor, major groups to just 'the next' version. In the prior
    example, the order of preference changes to "1.0.3, 1.0.4, 1.0.2, 1.1.0,
    1.1.1, 2.0.0"

  * `-s/--strict-updates` option will actually remove from consideration
    versions outside either the current patch version (or minor version if `-m`
    specified). This increases the chances of Bundler being unable to
    reconcile the dependency graph and could raise a `VersionConflict`.

`bundler-patch` will also check for vulnerabilities based on the
`ruby-advisory-db`, but also will _modify_ (if necessary) the gem requirement
in the Gemfile on vulnerable gems to ensure they can be upgraded.

  * `-l/--list` option will just list vulnerable gems. No updates will be
    performed.

  * `-a/--advisory-db-path` option can provide the path to an additional
    custom ruby-advisory-db styled directory. The path should not include the
    final `gems` directory, that will be appended automatically. This can be
    used for flagging necessary updates for custom/internal gems.
    
  * `-d/--ruby-advisory-db-path` option can override the default path where
    the ruby-advisory-db repository is checked out into.

The rules for updating vulnerable gems are almost identical to the general
`bundler-patch` behavior described above, and abide by the same options (`-m`,
`-p`, and `-s`) though there are some tweaks to encourage getting to at least
a patched version of the gem. Keep in mind Bundler may still choose unexpected
versions in order to satisfy the dependency graph.

   * `-v/--vulnerable-gems-only` option will automatically restrict the gems
     to update list to currently vulnerable gems. If a combination of `-v` and
     a list of gem names are passed, the `-v` option is ignored in favor of
     the listed gem names.

`bundler-patch` can also update the Ruby version listed in .ruby-version and
 the Gemfile if given a list of the latest Ruby versions that are available
 with the following options. Jumps of major versions will not be made at all
 and this feature is designed such that the version will be updated to only
 the next available in the list. If the current version is 2.3.1, and the list
 of `--rubies` is "2.3.2, 2.3.3", then 2.3.2 will be used, not 2.3.3. The 
 intention is for this list to be only the most recent version(s) of Ruby 
 supported, (e.g. "2.1.10, 2.2.7, 2.3.4").
 
   * `-r/--ruby` option indicates updates to Ruby version will be made.
   * `--rubies` a comma-delimited list of target Ruby versions to upgrade to. 

## Examples

### Single Gem

| Requirements| Locked  | Available                   | Options  | Result |
|-------------|---------|-----------------------------|----------|--------|
| foo         | 1.4.3   | 1.4.4, 1.4.5, 1.5.0, 1.5.1  |          | 1.4.5  |
| foo         | 1.4.3   | 1.4.4, 1.4.5, 1.5.0, 1.5.1  | -m       | 1.5.1  |
| foo         | 1.4.3   | 1.4.4, 1.4.5, 1.5.0, 1.5.1  | -p       | 1.4.4  |
| foo         | 1.4.3   | 1.4.4, 1.4.5, 1.5.0, 1.5.1  | -m -p    | 1.5.0  |

### Two Gems

Given the following gem specifications:

- foo 1.4.3, requires: ~> bar 2.0
- foo 1.4.4, requires: ~> bar 2.0
- foo 1.4.5, requires: ~> bar 2.1
- foo 1.5.0, requires: ~> bar 2.1
- foo 1.5.1, requires: ~> bar 3.0
- bar with versions 2.0.3, 2.0.4, 2.1.0, 2.1.1, 3.0.0

Gemfile: 

    gem 'foo'

Gemfile.lock: 

    foo (1.4.3)
      bar (~> 2.0)
    bar (2.0.3)

| # | Command Line              | Result                    |
|---|---------------------------|---------------------------|
| 1 | bundle patch              | 'foo 1.4.5', 'bar 2.1.1'  |
| 2 | bundle patch foo          | 'foo 1.4.4', 'bar 2.0.3'  |
| 3 | bundle patch -m           | 'foo 1.5.1', 'bar 3.0.0'  |
| 4 | bundle patch -m -s        | 'foo 1.5.0', 'bar 2.1.1'  |
| 5 | bundle patch -s           | 'foo 1.4.4', 'bar 2.0.4'  |
| 6 | bundle patch -p           | 'foo 1.4.4', 'bar 2.0.4'  |
| 7 | bundle patch -p -m        | 'foo 1.5.0', 'bar 2.1.0'  |

In case 1, `bar` is upgraded to 2.1.1, a minor version increase, because the
dependency from `foo` 1.4.5 required it.

In case 2, only `foo` is unlocked, so `foo` can only go to 1.4.4 to maintain
the dependency to `bar`.

In case 3, `bar` goes up a whole major release, because a minor increase is
preferred now for `foo`, and when it goes to 1.5.1, it requires 3.0.0 of
`bar`.

In case 4, `foo` is preferred up to a 1.5.x, but 1.5.1 won't work because the
strict `-s` flag removes `bar` 3.0.0 from consideration since it's a major
increment.

In case 5, both `foo` and `bar` have any minor or major increments removed
from consideration because of the `-s` strict flag, so the most they can
move is up to 1.4.4 and 2.0.4.

In case 6, the prefer minimal switch `-p` means they only increment to the
next available release.

In case 7, the `-p` and `-m` switches allow both to move to just the next
available minor version.


## Troubleshooting

First, make sure the current `bundle` command itself runs to completion on its
own without any problems.

The most frequent problems with this tool involve expectations around what
gems should or shouldn't be upgraded. This can quickly get complicated as even
a small dependency tree can involve many moving parts, and Bundler works hard
to find a combination that satisfies all of the dependencies and requirements.

NOTE: the requirements in the Gemfile trump anything else. The most control
you have is by modifying those in the Gemfile, in some circumstances it may be
better to pin your versions to what you need instead of trying to diagnose why
Bundler isn't calculating the versions you expect with a broader requirement.
If there is an incompatibility, pinning to desired versions can also aide in
debugging dependency conflicts.

You can get a (very verbose) look into how Bundler's resolution algorithm is
working by setting the `DEBUG_RESOLVER` environment variable. While it can be
tricky to dig through, it should explain how it came to the conclusions it
came to.

In particular, grep for 'Unwinding for conflict' in the debug output to
isolate some key issues that may be preventing the outcome you expect.

Adding to the usual Bundler complexity, `bundler-patch` is injecting its own
logic to the resolution process to achieve its goals. If there's a bug
involved, it's almost certainly in the `bundler-patch` code as Bundler has
been around a long time and has thorough testing and real world experience.

When used with versions of Bundler prior to 1.13, `bundler-patch` can dump
its own debug output, potentially helpful, with `DEBUG_PATCH_RESOLVER`.

(When used with version 1.13+ of Bundler, `bundler-patch` only adds some
additional sorting behavior, the result of which will be included in the
`DEBUG_RESOLVER` output and `DEBUG_PATCH_RESOLVER` is not used).

To get additional Bundler debugging output, enable the `DEBUG` env variable.
This will include all of the details of the downloading the full dependency
data from remote sources.

At the end of all of this though, again, the requirements in the Gemfile
trump anything else, and the most control you have is by modifying those
in the Gemfile.

## Breaking Changes from 0.x to 1.0

* Command line options with underscores now uses hyphens instead of 
  underscores. (Underscore versions will still work, but are undocumented).
  
* Some options have been renamed.
  

## Development

### How To

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/livingsocial/bundler-patch.

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).
