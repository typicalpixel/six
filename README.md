# Six

<picture>
  <img src="./assets/six.png" alt="Six">
</picture>

## Watch your Coverage

Zero-dependency Elixir coverage tool built for AI-assisted development. Wraps Erlang's `:cover` with smart defaults, function-level ignores, and a structured markdown report designed to be consumed directly by AI coding agents.

## Why Six

Erlang's `:cover` counts every executable line - including `defmodule`, `use`, `alias`, and other boilerplate that nobody considers "untested code." It also has no concept of ignoring specific functions or code blocks, and its output is designed for humans reading a terminal, not agents reading a file.

Six fixes all of that: smart defaults that exclude structural declarations, `@six :ignore` for function-level exclusions, comment directives for block-level control, and a structured markdown report at `.six/coverage.md` that tells an AI agent exactly which functions have untested branches - with source snippets and context. Zero dependencies beyond OTP.

## Installation

```elixir
# mix.exs
def project do
  [
    app: :my_app,
    test_coverage: [tool: Six],
    # ...
  ]
end

def cli do
  [preferred_envs: [six: :test, "six.detail": :test, "six.html": :test]]
end

defp deps do
  [{:six, "~> 0.1", only: :test}]
end
```

## Usage

```bash
# Run tests with coverage (terminal table + agent report)
mix test --cover

# Or use the mix task directly
mix six
mix six --threshold 90
mix six --minimum-coverage 85
mix six --skip generated/ --skip _pb.ex

# Source-level detail view
mix six.detail
mix six.detail --filter auth

# HTML report
mix six.html
mix six.html --open
```

This produces two things:

1. A terminal summary table (sorted worst-first)
2. `.six/coverage.md` - a structured report an AI agent can read and act on

## Guides

- [Reading the Output](https://hexdocs.pm/six/reading-output.html) - understanding the terminal table, columns, and colors
- [Threshold vs Minimum Coverage](https://hexdocs.pm/six/threshold-vs-minimum-coverage.html) - reporting targets vs enforcement floors
- [AI Integration](https://hexdocs.pm/six/ai-integration.html) - the agent report, Claude Code slash command, and coverage-driven test writing
- [GitHub Actions](https://hexdocs.pm/six/github-actions.html) - CI setup, failing on low coverage, and partitioned suites
- [Custom Formatters](https://hexdocs.pm/six/custom-formatters.html) - implementing the `Six.Formatter` behaviour

## Ignoring code

Three mechanisms, from automatic to explicit:

### Default pattern filters

Lines matching these patterns are automatically excluded from coverage - no configuration needed:

`defmodule`, `defprotocol`, `defimpl`, `defrecord`, `defdelegate`, `defstruct`, `defexception`, `@moduledoc`, `@doc`, `@impl`, `@behaviour`, `@callback`, `use`, `import`, `alias`, `require`, `plug`, `end`

### Function-level attribute

Add `use Six` to a module and tag functions with `@six :ignore`:

```elixir
defmodule MyApp.CoverBridge do
  use Six

  @six :ignore
  def start_cover do
    # Can't be tested during a coverage run
    :cover.start()
  end

  def normal_function do
    # This is still covered
    :ok
  end
end
```

`use Six` at the top of a file signals that the module has coverage exclusions - you know to look for `@six :ignore` tags. The attribute applies to the immediately following `def`/`defp`/`defmacro`/`defmacrop`, even with `@doc` or `@impl` in between.

### Comment directives

For quick one-offs where you don't need `use Six`:

```elixir
# six:ignore:next
def admin_only, do: System.halt(1)

# six:ignore:start
def debug_dump do
  # Everything in this block is excluded
end
# six:ignore:stop
```

Directive comments must be standalone comment lines. Six will not treat strings, heredocs, docs, or trailing inline comments that happen to contain `six:ignore:*` as coverage directives.

## Configuration

```elixir
# config/test.exs
config :six,
  # Additional patterns to ignore (beyond defaults)
  ignore_patterns: [
    ~r/^\s*@type\s/,
    ~r/^\s*defoverridable\s/
  ],

  # Set to false to ONLY use your patterns, not the built-in defaults
  default_patterns: true,

  # Fail CI if coverage drops below this
  minimum_coverage: 85.0,

  # File patterns to skip entirely
  skip_files: [
    ~r/lib\/my_app\/generated\//,
    ~r/_pb\.ex$/
  ],

  # Output directory (default: .six)
  output_dir: ".six",

  # Formatters to run (default: terminal + agent)
  formatters: [Six.Formatters.Terminal, Six.Formatters.Agent, Six.Formatters.HTML]
```

At runtime you can also override:

```bash
mix six --threshold 90
mix six --minimum-coverage 85
mix six --skip generated/ --skip _pb.ex
```

## Merging partitioned coverage

For CI setups that split tests across machines:

```bash
# Each partition exports its coverage data:
MIX_TEST_PARTITION=1 mix test --cover --export-coverage p1
MIX_TEST_PARTITION=2 mix test --cover --export-coverage p2

# Merge and generate report:
mix six --import-cover cover
```

## Acknowledgments

Six is built on top of Erlang's [:cover](https://www.erlang.org/doc/apps/tools/cover) and is inspired by [ExCoveralls](https://github.com/parroty/excoveralls) and [Coverex](https://github.com/alfert/coverex) - thank you!

## License

Copyright (c) 2026 Thomas Athanas

Licensed under the MIT License.
