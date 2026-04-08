defmodule Six.Config do
  @moduledoc false

  defstruct ignore_patterns: [],
            default_patterns: true,
            minimum_coverage: 0,
            output_dir: ".six",
            skip_files: [],
            formatters: [Six.Formatters.Terminal, Six.Formatters.Agent],
            detail: false,
            filter: nil,
            threshold: 90,
            track_ignores: false

  @doc """
  Reads configuration from application env and returns a config struct.
  """
  def read do
    %__MODULE__{
      ignore_patterns: get(:ignore_patterns, []),
      default_patterns: get(:default_patterns, true),
      minimum_coverage: get(:minimum_coverage, 0),
      output_dir: get(:output_dir, ".six"),
      skip_files: get(:skip_files, []),
      formatters: get(:formatters, [Six.Formatters.Terminal, Six.Formatters.Agent]),
      detail: get(:detail, false),
      filter: get(:filter, nil),
      threshold: get(:threshold, 90),
      track_ignores: get(:track_ignores, false)
    }
  end

  @doc """
  Merges runtime options (from mix task args or test_coverage opts) into config.
  """
  def merge_with_opts(%__MODULE__{} = config, opts) when is_list(opts) do
    Enum.reduce(opts, config, fn
      {:threshold, val}, acc -> %{acc | threshold: val}
      {:minimum_coverage, val}, acc -> %{acc | minimum_coverage: val}
      {:output_dir, val}, acc -> %{acc | output_dir: val}
      {:detail, val}, acc -> %{acc | detail: val}
      {:filter, val}, acc -> %{acc | filter: val}
      {:formatters, val}, acc -> %{acc | formatters: val}
      {:track_ignores, val}, acc -> %{acc | track_ignores: val}
      {:skip, val}, acc -> %{acc | skip_files: acc.skip_files ++ [val]}
      {:skip_files, vals}, acc when is_list(vals) -> %{acc | skip_files: acc.skip_files ++ vals}
      {:summary, summary_opts}, acc -> merge_summary_opts(acc, summary_opts)
      _, acc -> acc
    end)
  end

  defp merge_summary_opts(config, opts) when is_list(opts) do
    Enum.reduce(opts, config, fn
      {:threshold, val}, acc -> %{acc | threshold: val}
      _, acc -> acc
    end)
  end

  defp get(key, default) do
    Application.get_env(:six, key, default)
  end
end
