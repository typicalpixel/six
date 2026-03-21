defmodule Six.Filter do
  @moduledoc false

  @default_patterns [
    ~r/^\s*defmodule\s/,
    ~r/^\s*defprotocol\s/,
    ~r/^\s*defimpl\s/,
    ~r/^\s*defrecord\s/,
    ~r/^\s*defdelegate\s/,
    ~r/^\s*defstruct\s/,
    ~r/^\s*defexception\s/,
    ~r/^\s*@moduledoc\s/,
    ~r/^\s*@doc\s/,
    ~r/^\s*@impl\s/,
    ~r/^\s*@behaviour\s/,
    ~r/^\s*@callback\s/,
    ~r/^\s*use\s/,
    ~r/^\s*import\s/,
    ~r/^\s*alias\s/,
    ~r/^\s*require\s/,
    ~r/^\s*plug\s/,
    ~r/^\s*plug\(/,
    ~r/^\s*(end)\s*$/
  ]

  @doc """
  Filters coverage data by nullifying lines matching configured patterns.
  """
  def run(file_stats_list, config) do
    patterns = compile_patterns(config)

    Enum.map(file_stats_list, fn file_stats ->
      filter_file(file_stats, patterns)
    end)
  end

  @doc """
  Compiles patterns from config, merging with defaults if configured.
  """
  def compile_patterns(%{default_patterns: use_defaults, ignore_patterns: user_patterns}) do
    base = if use_defaults, do: @default_patterns, else: []
    base ++ compile_user_patterns(user_patterns)
  end

  def compile_patterns(_), do: @default_patterns

  defp compile_user_patterns(patterns) do
    Enum.map(patterns, fn
      %Regex{} = r -> r
      str when is_binary(str) -> Regex.compile!(str)
    end)
  end

  defp filter_file(%{source: source, coverage: coverage} = file_stats, patterns) do
    source_lines = String.split(source, "\n")

    new_coverage =
      source_lines
      |> Enum.zip(coverage)
      |> Enum.map(fn {line, cov} ->
        if cov != nil && matches_any?(line, patterns) do
          nil
        else
          cov
        end
      end)

    Six.Stats.recalculate(%{file_stats | coverage: new_coverage})
  end

  defp matches_any?(line, patterns) do
    Enum.any?(patterns, &Regex.match?(&1, line))
  end
end
