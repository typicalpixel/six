defmodule Six.Formatters.Agent do
  @moduledoc false
  @behaviour Six.Formatter

  @max_snippet_lines 15

  @impl true
  def format(summary, opts \\ []) do
    output_dir = Keyword.get(opts, :output_dir, ".six")
    path = Path.join(output_dir, "coverage.md")

    content = render(summary, opts)

    File.mkdir_p!(output_dir)
    File.write!(path, content)
    IO.puts("Agent report written to #{path}")
    :ok
  end

  @impl true
  def output_path(opts) do
    Path.join(Keyword.get(opts, :output_dir, ".six"), "coverage.md")
  end

  @doc false
  def render(summary, opts) do
    threshold = Keyword.get(opts, :threshold, 90)
    threshold_status = if summary.percentage >= threshold, do: "✅", else: "❌"

    {uncovered, covered} =
      Enum.split_with(summary.files, fn f -> f.missed > 0 end)

    uncovered = Enum.sort_by(uncovered, & &1.percentage)

    [
      "# Six Coverage Report\n",
      "**Total: #{format_pct(summary.percentage)}** (#{summary.total_covered}/#{summary.total_relevant} relevant lines covered)\n",
      "**Generated:** #{DateTime.utc_now() |> DateTime.to_iso8601()}\n",
      "**Threshold:** #{format_pct(threshold)} #{threshold_status}\n",
      render_uncovered(uncovered),
      render_covered(covered),
      render_ignored(summary.files),
      render_summary(summary, threshold)
    ]
    |> IO.iodata_to_binary()
  end

  defp render_uncovered([]), do: ""

  defp render_uncovered(files) do
    sections =
      Enum.map(files, fn file ->
        source_lines = String.split(file.source, "\n")
        functions = Six.Ignore.Functions.functions(file.source)
        groups = group_missed_lines(file.coverage)

        group_sections =
          Enum.map(groups, fn {start_line, end_line} ->
            function_entry = function_for_line(functions, start_line)
            func_name = display_name(function_entry)
            branch_ctx = detect_branch_context(source_lines, {start_line, end_line})
            snippet = extract_source_block(source_lines, start_line, end_line)

            description = build_description(function_entry, branch_ctx, file.coverage)

            [
              "- **Lines #{start_line}-#{end_line}**",
              if(func_name, do: " — `#{func_name}`", else: ""),
              if(description, do: " — #{description}", else: ""),
              "\n",
              "  ```elixir\n",
              indent_snippet(snippet),
              "  ```\n\n"
            ]
          end)

        [
          "\n### #{file.path} — #{format_pct(file.percentage)} (#{file.covered}/#{file.relevant})\n\n",
          "**Missed lines:**\n\n",
          group_sections
        ]
      end)

    ["\n## Uncovered files (worst first)\n" | sections]
  end

  defp render_covered([]), do: "\n## Fully covered files\n\n_None_\n"

  defp render_covered(files) do
    lines = Enum.map(files, fn f -> "- #{f.path} — #{format_pct(f.percentage)}\n" end)
    ["\n## Fully covered files\n\n" | lines]
  end

  defp render_ignored(files) do
    all_ignored =
      Enum.flat_map(files, fn file ->
        comment_ranges = Six.Ignore.ignored_ranges(file.source)
        func_ranges = Six.Ignore.Functions.ignored_functions(file.source)

        comment_entries =
          Enum.map(comment_ranges, fn {start_line, end_line, type} ->
            type_label = if type == :block, do: "six:ignore:start/stop", else: "six:ignore:next"

            %{
              path: file.path,
              start_line: start_line,
              end_line: end_line,
              label: type_label,
              function: nil
            }
          end)

        func_entries =
          Enum.map(func_ranges, fn %{start_line: s, end_line: e, function: func} ->
            %{path: file.path, start_line: s, end_line: e, label: "@six :ignore", function: func}
          end)

        comment_entries ++ func_entries
      end)

    if all_ignored == [] do
      ""
    else
      lines =
        Enum.map(all_ignored, fn entry ->
          range = "#{entry.path}:#{entry.start_line}-#{entry.end_line}"
          func_part = if entry.function, do: " `#{entry.function}`", else: ""
          "- #{range}#{func_part} — #{entry.label}\n"
        end)

      ["\n## Ignored\n\n" | lines]
    end
  end

  defp render_summary(summary, threshold) do
    below = Enum.count(summary.files, fn f -> f.percentage < threshold end)
    file_count = length(summary.files)

    [
      "\n## Summary\n\n",
      "#{file_count} files, #{summary.total_relevant} relevant lines, ",
      "#{summary.total_covered} covered, #{summary.total_missed} missed.\n",
      if(below > 0, do: "#{below} files below threshold (#{format_pct(threshold)}).\n", else: "")
    ]
  end

  @doc false
  def group_missed_lines(coverage) do
    coverage
    |> Enum.with_index(1)
    |> Enum.filter(fn {cov, _} -> cov == 0 end)
    |> Enum.map(fn {_, idx} -> idx end)
    |> group_contiguous()
  end

  defp group_contiguous([]), do: []

  defp group_contiguous([first | rest]) do
    {groups, current_start, current_end} =
      Enum.reduce(rest, {[], first, first}, fn line, {groups, start, prev} ->
        if line == prev + 1 do
          {groups, start, line}
        else
          {[{start, prev} | groups], line, line}
        end
      end)

    Enum.reverse([{current_start, current_end} | groups])
  end

  @doc false
  def attribute_to_function(source_lines, {start_line, _end_line}) do
    source_lines
    |> Enum.join("\n")
    |> Six.Ignore.Functions.functions()
    |> function_for_line(start_line)
    |> display_name()
  end

  @doc false
  def detect_branch_context(source_lines, {start_line, _end_line}) do
    # Check lines at and near the start of the missed range for branch context
    range_start = max(start_line - 3, 0)
    context_lines = Enum.slice(source_lines, range_start, start_line - range_start + 1)
    missed_line = Enum.at(source_lines, start_line - 1, "")
    trimmed = String.trim(missed_line)

    cond do
      # Pattern match in case/cond
      Regex.match?(~r/^\{:error/, trimmed) ->
        "the `{:error, ...}` branch"

      Regex.match?(~r/^\{:ok/, trimmed) ->
        "the `{:ok, ...}` branch"

      Regex.match?(~r/^:error/, trimmed) ->
        "the `:error` branch"

      String.starts_with?(trimmed, "else") ->
        "the `else` branch"

      String.starts_with?(trimmed, "false") ->
        "the `false` branch"

      String.starts_with?(trimmed, "nil") ->
        "the `nil` branch"

      # Check if we're inside a with else block
      any_line_matches?(context_lines, ~r/\belse\b/) ->
        "the `else` clause"

      # Check for arrow clauses in case/cond
      Regex.match?(~r/->$/, trimmed) ->
        pattern = String.trim_trailing(trimmed, "->") |> String.trim()
        "the `#{pattern}` branch"

      true ->
        nil
    end
  end

  defp any_line_matches?(lines, pattern) do
    Enum.any?(lines, &Regex.match?(pattern, &1))
  end

  defp build_description(function_entry, branch_ctx, coverage) do
    cond do
      function_entry && entire_function_missed?(function_entry, coverage) ->
        "entire function untested"

      branch_ctx ->
        branch_ctx

      true ->
        nil
    end
  end

  defp entire_function_missed?(%{start_line: start_line, end_line: end_line}, coverage) do
    coverage
    |> Enum.slice((start_line - 1)..(end_line - 1))
    |> Enum.all?(fn
      nil -> true
      0 -> true
      _ -> false
    end)
  end

  defp function_for_line(functions, line_num) do
    functions
    |> Enum.filter(fn %{start_line: start_line, end_line: end_line} ->
      line_num >= start_line and line_num <= end_line
    end)
    |> Enum.max_by(
      fn %{start_line: start_line, end_line: end_line} ->
        {start_line, -end_line}
      end,
      fn -> nil end
    )
  end

  defp display_name(nil), do: nil

  defp display_name(%{function: function}) do
    case String.split(function, " ", parts: 2) do
      [_kind, name] -> name
      _ -> function
    end
  end

  @doc false
  def extract_source_block(source_lines, start_line, end_line) do
    lines = Enum.slice(source_lines, (start_line - 1)..(end_line - 1))
    line_count = length(lines)

    if line_count > @max_snippet_lines do
      first = Enum.take(lines, 5)
      last = Enum.take(lines, -5)
      remaining = line_count - 10

      first ++ ["  # ... #{remaining} more lines ..."] ++ last
    else
      lines
    end
  end

  defp indent_snippet(lines) do
    lines
    |> Enum.map(fn line -> "  " <> line <> "\n" end)
    |> IO.iodata_to_binary()
  end

  defp format_pct(pct) do
    :erlang.float_to_binary(pct / 1, decimals: 1) <> "%"
  end
end
