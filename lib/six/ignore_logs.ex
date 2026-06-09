defmodule Six.Ignore.Logs do
  @moduledoc """
  Excludes log statements from coverage based on their level.

  `Logger` macros check the configured level *before* evaluating their message
  and metadata. A test suite usually runs with `config :logger, level: :warning`,
  so the arguments of an `info`/`debug` call are never executed — and `:cover`
  reports those lines as missed even though no test could cover them. (`warning`
  and `error` calls still emit, so they stay coverable.)

  For every level listed in the `:ignore_log_levels` config, this stage nullifies
  the coverage of matching `Logger` calls, spanning the whole statement —
  including multi-line metadata — via the AST. It is a no-op by default.
  """

  @valid_levels [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

  @aliases %{warn: :warning}

  @doc """
  Nullifies coverage for log calls whose level is listed in `:ignore_log_levels`.

  A no-op when `:ignore_log_levels` is empty (the default), so existing projects
  see no change until they opt in.
  """
  def run(file_stats_list, config)

  def run(file_stats_list, %{ignore_log_levels: levels}) when is_list(levels) and levels != [] do
    case normalize_levels(levels) do
      [] ->
        file_stats_list

      ignore_levels ->
        ignore_set = MapSet.new(ignore_levels)
        Enum.map(file_stats_list, &process_file(&1, ignore_set))
    end
  end

  def run(file_stats_list, _config), do: file_stats_list

  defp process_file(%{source: source, coverage: coverage} = file_stats, ignore_set) do
    case ignored_ranges(source, ignore_set) do
      [] ->
        file_stats

      ranges ->
        new_coverage =
          coverage
          |> Enum.with_index(1)
          |> Enum.map(fn {cov, line_num} ->
            if in_any_range?(line_num, ranges), do: nil, else: cov
          end)

        Six.Stats.recalculate(%{file_stats | coverage: new_coverage})
    end
  end

  @doc """
  Returns `{start_line, end_line}` ranges for every `Logger` call in `source`
  whose level is a member of `ignore_set`.

  Spans are taken from the AST, so a multi-line call (including its metadata)
  is captured whole. Unparseable source yields no ranges.
  """
  def ignored_ranges(source, ignore_set) do
    {parsed, _diagnostics} =
      Code.with_diagnostics(fn ->
        Code.string_to_quoted(source, columns: true, token_metadata: true)
      end)

    case parsed do
      {:ok, ast} -> collect_ranges(ast, ignore_set)
      {:error, _} -> []
    end
  end

  @doc """
  Canonicalizes configured levels (mapping the deprecated `:warn` to `:warning`)
  and drops unknown levels with a warning.
  """
  def normalize_levels(levels) do
    {valid, invalid} = Enum.split_with(levels, &valid_level?/1)

    if invalid != [] do
      IO.warn(
        "Six: ignoring unknown log level(s) in :ignore_log_levels: #{inspect(invalid)}. " <>
          "Valid levels: #{inspect(@valid_levels)}"
      )
    end

    valid |> Enum.map(&canonical/1) |> Enum.uniq()
  end

  defp valid_level?(level), do: is_atom(level) and canonical(level) in @valid_levels

  defp canonical(level), do: Map.get(@aliases, level, level)

  defp collect_ranges(ast, ignore_set) do
    {_ast, ranges} =
      Macro.prewalk(ast, [], fn node, acc ->
        case log_range(node, ignore_set) do
          nil -> {node, acc}
          range -> {node, [range | acc]}
        end
      end)

    Enum.reverse(ranges)
  end

  # `Logger.log(level, ...)` carries the level as its first argument.
  defp log_range(
         {{:., _, [{:__aliases__, _, [:Logger]}, :log]}, meta, [level | _] = args},
         ignore_set
       )
       when is_atom(level) do
    maybe_range(canonical(level), meta, args, ignore_set)
  end

  # `Logger.debug/info/warning/error/...(message, metadata)`.
  defp log_range(
         {{:., _, [{:__aliases__, _, [:Logger]}, level]}, meta, args},
         ignore_set
       )
       when is_atom(level) and is_list(args) do
    maybe_range(canonical(level), meta, args, ignore_set)
  end

  defp log_range(_node, _ignore_set), do: nil

  defp maybe_range(level, meta, args, ignore_set) do
    if MapSet.member?(ignore_set, level), do: span(meta, args), else: nil
  end

  # End line is the closing paren when present, else the deepest argument line
  # (so paren-less multi-line calls are still spanned whole).
  defp span(meta, args) do
    start_line = meta[:line]

    end_line =
      [start_line, meta[:closing][:line], deep_max_line(args, start_line)]
      |> Enum.reject(&is_nil/1)
      |> Enum.max()

    {start_line, end_line}
  end

  defp deep_max_line(ast, default) do
    {_ast, max_line} =
      Macro.prewalk(ast, default, fn
        {_form, meta, _args} = node, acc when is_list(meta) ->
          line = meta[:line]
          {node, if(is_integer(line) and line > acc, do: line, else: acc)}

        node, acc ->
          {node, acc}
      end)

    max_line
  end

  defp in_any_range?(line_num, ranges) do
    Enum.any?(ranges, fn {start_line, end_line} ->
      line_num >= start_line and line_num <= end_line
    end)
  end
end
