# Contributing to Six

Thanks for your interest in contributing! Please take a moment to review this document before submitting a pull request.

## Getting started

```bash
git clone https://github.com/typicalpixel/six.git
cd six
mix deps.get
mix test --cover
```

Six is designed to be used on itself. After running `mix test --cover`, check `.six/coverage.md` for the report. Coverage should currently land at `100.0%`.

## Bug reports

Use the [GitHub issue tracker](https://github.com/typicalpixel/six/issues). A good bug report includes:

1. Your Elixir and OTP versions
2. Steps to reproduce
3. Expected vs actual behavior

## Pull requests

1. Fork the repo and create a topic branch off `main`
2. Make your changes and add tests
3. Run `mix test --cover` and confirm coverage stays at 100%
4. Push your branch and open a pull request with a clear description

Keep pull requests focused — one feature or fix per PR.

## Code style

Follow the conventions already in the codebase. Run `mix format` before committing.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
