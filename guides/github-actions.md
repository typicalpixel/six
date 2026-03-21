# GitHub Actions

Minimal example:

```yaml
name: test

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.18.3"
          otp-version: "27.0"

      - name: Cache deps and build
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('mix.lock') }}

      - name: Install deps
        run: mix deps.get

      - name: Run tests with coverage
        run: mix test --cover

      - name: Upload Six report
        uses: actions/upload-artifact@v4
        with:
          name: six-report
          path: .six/coverage.md
```

## Failing CI on low coverage

Either set `minimum_coverage` in `config/test.exs` or call:

```bash
mix six --minimum-coverage 85
```

## HTML output in CI

Run `mix six.html` or add the built-in HTML formatter in your config:

```elixir
config :six,
  formatters: [Six.Formatters.Terminal, Six.Formatters.Agent, Six.Formatters.HTML]
```

## Partitioned test suites

If your CI splits tests across partitions, export coverage from each partition and merge with `mix six --import-cover ...` in a follow-up job.
