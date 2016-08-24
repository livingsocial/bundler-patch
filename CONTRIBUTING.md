# Contributing

First, thank you for contributing!

Here are a few technical guidelines to follow:

1. Open an issue to discuss a new feature.
2. Write tests.
3. Make sure the entire test suite passes locally and on CI.
4. Open a Pull Request.
5. Address comments after receiving feedback.
6. Party!

Bug reports and pull requests are welcome on GitHub at
https://github.com/livingsocial/bundler-patch.

### How To

After checking out the repo, run `bin/setup` to install dependencies. You can also run
`bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Testing

Run tests with Rake:

```
$ bundle exec rake test:all          # Run all RSpec code examples
$ bundle exec rake test:integration  # Run RSpec integration code examples
$ bundle exec rake test:unit         # Run RSpec unit code examples
```

You need to supply the version of Bundler you're using for testing, e.g.:

```
$ BUNDLER_TEST_VERSION=1.12.4 bundle exec rake test:all
```

Example to run a single test:

```
$ BUNDLER_TEST_VERSION=1.12.4 bundle exec rspec spec/bundler/unit/bundler_version_spec.rb
```
