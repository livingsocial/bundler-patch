# Conservative Bundle Updates

Starting with 1.13.0.rc.2, a subset of bundler-patch behavior was ported to Bundler itself.
The plan is to leave it undocumented and unsupported in 1.13 to give it a chance to 
be used and flush out bugs and iron out some design decisions.

Part of that work before 1.14 (or maybe a later version) will be to properly document
`bundle update` as well as the [Conservative Updating](http://bundler.io/v1.12/man/bundle-install.1.html#CONSERVATIVE-UPDATING)
section of `bundle install`, but right now we need a placeholder document showing the new
stuff so folks know how to use it.

This is largely copy/pasta of the bundler-patch [README](README.md).

## Usage

The default `bundle update` behavior remains untouched. Use of the new `--patch`
or `--minor` options will invoke the new conservative update behavior.

"Conservative" means it will sort all available versions to prefer the
latest releases from the current version, then the latest minor releases and
then the latest major releases.

"Prefer" means that no available versions are removed from consideration, to
help ensure a suitable dependency graph can be reconciled. This does mean some
gems cannot be upgraded or may be upgraded to unexpected versions. NOTE: There is
a `--strict` option which _will_ remove versions from consideration, see below.

Gem requirements as defined in the Gemfile will still define what versions are available.
The new conservative behavior controls the preference order of those versions.

For example, if gem 'foo' is locked at 1.0.2, with no gem requirement defined
in the Gemfile, and versions 1.0.3, 1.0.4, 1.1.0, 1.1.1, 2.0.0 all exist, the
default order of preference will be "1.0.4, 1.0.3, 1.0.2, 1.1.1, 1.1.0,
2.0.0".

In the same example, if gem 'foo' has a requirement of '~> 1.0', version 2.0.0
will be removed from consideration as always.

With no gem names provided on the command line, all gems will be unlocked and
open for updating. 

    $ bundle update --patch 

A list of gem names can be passed to restrict to just those gems.

    $ bundle update --patch foo bar

  * `--patch` option will give preference for release/patch versions, then minor,
    then major.
    
  * `--minor` option will give preference for minor versions over
    release versions, then major versions.

  * `--major` option will give preference for major versions over
    minor or release versions. This is the default behavior currently, so this
    flag is cosmetic for now. Bundler 2.0 will likely make `--patch` the default
    behavior.

  * `--strict` option will actually remove from consideration
    versions outside either the current release (or minor version if `--minor`
    specified). This increases the chances of Bundler being unable to
    reconcile the dependency graph and in some cases could even raise a 
    `VersionConflict`.

## Examples

### Single Gem

| Requirements| Locked  | Available                         | Option   | Result |
|-------------|---------|-----------------------------------|----------|--------|
| foo         | 1.4.3   | 1.4.4, 1.4.5, 1.5.0, 1.5.1, 2.0.0 | --patch  | 1.4.5  |
| foo         | 1.4.3   | 1.4.4, 1.4.5, 1.5.0, 1.5.1, 2.0.0 | --minor  | 1.5.1  |
| foo         | 1.4.3   | 1.4.4, 1.4.5, 1.5.0, 1.5.1, 2.0.0 | --major  | 2.0.0  |

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

| # | Command Line                   | Result                    |
|---|--------------------------------|---------------------------|
| 1 | bundle update --patch          | 'foo 1.4.5', 'bar 2.1.1'  |
| 2 | bundle update --patch foo      | 'foo 1.4.5', 'bar 2.1.1'  |
| 3 | bundle update --minor          | 'foo 1.5.1', 'bar 3.0.0'  |
| 4 | bundle update --minor --strict | 'foo 1.5.0', 'bar 2.1.1'  |
| 5 | bundle update --patch --strict | 'foo 1.4.4', 'bar 2.0.4'  |

In case 1, `bar` is upgraded to 2.1.1, a minor version increase, because the
dependency from `foo` 1.4.5 required it.

In case 2, only `foo` is unlocked, but because no other gem depends on `bar`
and `bar` is not a declared dependency in the Gemfile, `bar` is free to move, 
and so the result is the same as case 1. 

In case 3, `bar` goes up a whole major release, because a minor increase is
preferred now for `foo`, and when it goes to 1.5.1, it requires 3.0.0 of
`bar`.

In case 4, `foo` is preferred up to a 1.5.x, but 1.5.1 won't work because the
`--strict` flag removes `bar` 3.0.0 from consideration since it's a major
increment.

In case 5, both `foo` and `bar` have any minor or major increments removed
from consideration because of the `--strict` flag, so the most they can
move is up to 1.4.4 and 2.0.4.

### Shared Dependencies

#### Shared Cannot Move

Given the following gem specifications:

- foo 1.4.3, requires: ~> shared 2.0, ~> bar 2.0
- foo 1.4.4, requires: ~> shared 2.0, ~> bar 2.0
- foo 1.4.5, requires: ~> shared 2.1, ~> bar 2.1
- foo 1.5.0, requires: ~> shared 2.1, ~> bar 2.1
- qux 1.0.0, requires: ~> shared 2.0.0           
- bar with versions 2.0.3, 2.0.4, 2.1.0, 2.1.1
- shared with versions 2.0.3, 2.0.4, 2.1.0, 2.1.1

Gemfile: 

    gem 'foo'
    gem 'qux'

Gemfile.lock: 

    bar (2.0.3)
    foo (1.4.3)
      bar (~> 2.0)
      shared (~> 2.0)
    qux (1.0.0)
      shared (~> 2.0.0)
    shared (2.0.3)
    

| # | Command Line                   | Result                                    |
|---|--------------------------------|-------------------------------------------|
| 1 | bundle update --patch foo      | 'foo 1.4.4', 'bar 2.0.3', 'shared 2.0.3'  |
| 2 | bundle update --patch foo bar  | 'foo 1.4.4', 'bar 2.0.4', 'shared 2.0.3'  |
| 3 | bundle update --patch          | 'foo 1.4.4', 'bar 2.0.4', 'shared 2.0.4'  |

In case 1, only `foo` moves. When `foo` 1.4.5 is considered in resolution, it 
would require `shared` 2.1 which isn't allowed because `qux` is incompatible. 
Resolution backs up to `foo` 1.4.4, and that is allowed by the `qux` constraint
on `shared` so `foo` moves. `bar` could legally move, but since it is locked 
and the current version still satisfies the requirement of `~> 2.0` it stays 
put.

In case 2, everything is the same, but `bar` is also unlocked, so it is also
allowed to increment to 2.0.4 which still satisfies `~> 2.0`.

In case 3, everything is unlocked, so `shared` can also bump up a patch version.

#### Shared Can Move

_*This is exactly the same setup as "Shared Cannot Move" except for one change.*_

The `qux` gem has a looser requirement of `shared`: `~> 2.0` instead of `~> 2.0.0`.

Given the following gem specifications:

- foo 1.4.3, requires: ~> shared 2.0, ~> bar 2.0
- foo 1.4.4, requires: ~> shared 2.0, ~> bar 2.0
- foo 1.4.5, requires: ~> shared 2.1, ~> bar 2.1
- foo 1.5.0, requires: ~> shared 2.1, ~> bar 2.1
- qux 1.0.0, requires: ~> shared 2.0           
- bar with versions 2.0.3, 2.0.4, 2.1.0, 2.1.1
- shared with versions 2.0.3, 2.0.4, 2.1.0, 2.1.1

Gemfile: 

    gem 'foo'
    gem 'qux'

Gemfile.lock: 

    bar (2.0.3)
    foo (1.4.3)
      bar (~> 2.0)
      shared (~> 2.0)
    qux (1.0.0)
      shared (~> 2.0)
    shared (2.0.3)
    

| # | Command Line                   | Result                                    |
|---|--------------------------------|-------------------------------------------|
| 1 | bundle update --patch foo      | 'foo 1.4.5', 'bar 2.1.1', 'shared 2.1.1'  |
| 2 | bundle update --patch foo bar  | 'foo 1.4.5', 'bar 2.1.1', 'shared 2.1.1'  |
| 3 | bundle update --patch          | 'foo 1.4.5', 'bar 2.1.1', 'shared 2.1.1'  |

In all 3 cases, because `foo` 1.4.5 depends on newer versions of `bar` and 
`shared`, and no requirements from `qux` are restricting those two from moving, 
then all move as far as allowed here.
 
`foo` can only move to 1.4.5 and not 1.5.0 because of the `--patch` flag. 
 
As previously demonstrated (see Two Cases) `bar` and `shared` move past the 
`--patch` restriction because `--strict` is not in play, they are not declared 
dependencies in the Gemfile and they need to move to satisfy the new `foo` 
requirement.

### Bundle Install Like Conservative Updating

As detailed in [Bundle Install Docs](http://bundler.io/v1.13/man/bundle-install.1.html#CONSERVATIVE-UPDATING)
there is a way to prevent shared dependencies from moving after (a) changing 
a requirement in the Gemfile and (b) using `bundle install`. There's currently
not an equivalent way to do this with `bundler-patch` or `bundle update` but
this may change in the future.

### Troubleshooting

First, make sure the current `bundle` command itself runs to completion on its
own without any problems.

The most frequent problems involve expectations around what
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

To get additional Bundler debugging output, enable the `DEBUG` env variable.
This will include all of the details of the downloading the full dependency
data from remote sources.

At the end of all of this though, again, the requirements in the Gemfile
trump anything else, and the most control you have is by modifying those
in the Gemfile.
