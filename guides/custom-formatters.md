# Custom Formatters

Implement the `Six.Formatter` behaviour:

```elixir
defmodule MyApp.LCOVFormatter do
  @behaviour Six.Formatter

  @impl true
  def format(summary, opts) do
    # summary contains: files, total_lines, total_relevant,
    # total_covered, total_missed, percentage
    # Each file has: path, source, coverage, lines, relevant,
    # covered, missed, percentage
    :ok
  end
end
```

Register your formatter in config:

```elixir
config :six,
  formatters: [Six.Formatters.Terminal, MyApp.LCOVFormatter]
```
