# Threshold vs Minimum Coverage

`threshold` and `minimum_coverage` solve different problems:

- `threshold` is a reporting target. It controls formatter highlighting and pass/fail status in the terminal, HTML, and markdown reports, but it does not fail the command.
- `minimum_coverage` is an enforcement floor. If total coverage drops below it, Six exits non-zero and can fail your CI job.

## Example

```elixir
config :six,
  threshold: 90,
  minimum_coverage: 85
```

If total coverage is `88.0%`:

- the report shows you are below the `90%` target
- the run still passes, because `88.0 >= 85.0`

If total coverage is `82.0%`:

- the report shows you are below target
- the run fails, because `82.0 < 85.0`

## When to use each

- **Local development**: use `threshold` when you want a visible target without blocking your workflow.
- **CI**: use `minimum_coverage` when you want coverage regressions to fail the build.
- **Both**: use `threshold` as the aspirational goal and `minimum_coverage` as the hard floor. This is usually the most practical setup.
