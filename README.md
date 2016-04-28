# bundler-patch

`bundler-patch` can update your gems conservatively to deal with vulnerable
gems or just get more current.

By default, "conservatively" means it will prefer the latest releases from the
current version, over the latest minor releases or the latest major releases.
This is somewhat opposite from `bundle update` which prefers newest/major
versions first.

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

"Conservatively" means it will sort all available versions to prefer the
latest releases from the current version, then the latest minor releases and
then the latest major releases.

Gem requirements as defined in the Gemfile will restrict the available version
options.

For example, if gem 'foo' is locked at 1.0.2, with no gem requirement defined
in the Gemfile, and versions 1.0.3, 1.0.4, 1.1.0, 1.1.1, 2.0.0 all exist, the
default order of preference will be "1.0.4, 1.0.3, 1.0.2, 1.1.1, 1.1.0,
2.0.0".

"Prefer" means that no available versions are removed from consideration*, to
help ensure a suitable dependency graph can be reconciled. This does mean some
gems cannot be upgraded or will be upgraded to unexpected versions.

_*That's a white-lie. bundler-patch will actually remove from consideration
any versions older than the currently locked version, which `bundle update`
will not do. It's not common, but it is possible for `bundle update` to
regress a gem to an older version, if necessary to reconcile the dependency
graph._

With no gem names provided on the command line, all gems will be unlocked and
open for updating. A list of gem names can be passed to restrict to just those
gems.

    $ bundle patch foo bar

  * `-m/--minor_preferred` option will give preference for minor versions over
    release versions.

  * `-p/--prefer_minimal` option will reverse the preference order within
    release, minor, major groups to just 'the next' version. In the prior
    example, the order of preference changes to "1.0.3, 1.0.4, 1.0.2, 1.1.0,
    1.1.1, 2.0.0"

  * `-s/--strict_updates` option will actually remove from consideration
    versions outside either the current release (or minor version if `-m`
    specified). This increases the chances of Bundler being unable to
    reconcile the dependency graph and could raise a `VersionConflict`.

`bundler-patch` will also check for vulnerabilities based on the
`ruby-advisory-db`, but also will _modify_ (if necessary) the gem requirement
in the Gemfile on vulnerable gems to ensure they can be upgraded.

  * `-l/--list` option will just list vulnerable gems. No updates will be
    performed.

  * `-a/--advisory_db_path` option can provide the path to an additional
    custom ruby-advisory-db styled directory. The path should not include the
    final `gems` directory, that will be appended automatically. This can be
    used for flagging necessary updates for custom/internal gems.

The rules for updating vulnerable gems are almost identical to the general
`bundler-patch` behavior described above, and abide by the same options (`-m`,
`-p`, and `-s`) though there are some tweaks to encourage getting to at least
a patched version of the gem. Keep in mind Bundler may choose unexpected
versions in order to satisfy the dependency graph.

   * `-v/--vulnerable_gems_only` option will automatically restrict the gems
     to update list to currently vulnerable gems. If a combination of `-v` and
     a list of gem names are passed, the `-v` option is ignored in favor of
     the listed gem names.


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

| # | Command Line | Result                    |
|---|--------------|---------------------------|
| 1 |              | 'foo 1.4.5', 'bar 2.1.1'  |
| 2 | foo          | 'foo 1.4.4', 'bar 2.0.3'  |
| 3 | -m           | 'foo 1.5.1', 'bar 3.0.0'  |
| 4 | -m -s        | 'foo 1.5.0', 'bar 2.1.1'  |
| 5 | -s           | 'foo 1.4.4', 'bar 2.0.4'  |
| 6 | -p           | 'foo 1.4.4', 'bar 2.0.4'  |
| 7 | -p -m        | 'foo 1.5.0', 'bar 2.1.0'  |

In case 1, `bar` is upgraded to 2.1.0, a minor version increase, because the
dependency from `foo` 1.4.5 required it.

In case 2, only `foo` is unlocked, so `bar` can only go to 1.4.4 to satisfy
the dependency from `foo`.

In case 3, `bar` goes up a whole major release, because a minor increase is
preferred now for `foo`.

In case 4, `foo` is preferred up to a 1.5.x, but 1.5.1 won't work because the
strict `-s` flag removes `bar` 3.0.0 from consideration since it's a major
increment.

In case 5, both `foo` and `bar` have any minor or major increments removed
from consideration, so the most they can move is up to 1.4.4 and 2.0.4.

In case 6, the prefer minimal switch `-p` means they only increment to the
next available release.

In case 7, the `-p` and `-m` switches allow both to move to just the next
available minor version.


### Troubleshooting

First, make sure the current `bundle` command itself runs to completion on its
own without any problems.

The most frequent problems with this tool involve expectations around what
gems should or shouldn't be upgraded. This can quickly get complicated as even
a small dependency tree can involve many moving parts, and Bundler works hard
to find a combination that satisfies all of the dependencies and requirements.

You can get a (very verbose) look into how Bundler's resolution algorithm is
working by setting the `DEBUG_RESOLVER` environment variable. While it can be
tricky to dig through, it should explain how it came to the conclusions it
came to.

Adding to the usual Bundler complexity, `bundler-patch` is injecting its own
logic to the resolution process to achieve its goals. If there's a bug
involved, it's almost certainly in the `bundler-patch` code as Bundler has
been around a long time and has thorough testing and real world experience.

In particular, grep for 'Unwinding for conflict' to isolate some key issues
that may be preventing the outcome you expect.

`bundler-patch` can dump its own debug output, potentially helpful, with
`DEBUG_PATCH_RESOLVER`.

To get additional Bundler debugging output, enable the `DEBUG` env variable.
This will include all of the details of the downloading the full dependency
data from remote sources.


## Development

### Status

0.x versions are subject to breaking changes, there's a fair amount of
experimenting going on.

We'd love to get real world scenarios where things don't go as planned to help
flesh out varying details of what many believe a conservative update should
be.

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
