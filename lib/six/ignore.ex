defmodule Six.Ignore do
  @moduledoc false

  @directive_patterns %{
    start: ~r/^\s*#\s*six:ignore:start\s*$/,
    stop: ~r/^\s*#\s*six:ignore:stop\s*$/,
    next: ~r/^\s*#\s*six:ignore:next\s*$/
  }

  @doc """
  Processes comment-based ignore directives in source files.
  Returns {updated_file_stats_list, warnings}.
  """
  def run(file_stats_list) do
    {results, all_warnings} =
      Enum.map_reduce(file_stats_list, [], fn file_stats, warnings ->
        {updated, file_warnings} = process_file(file_stats)
        {updated, warnings ++ file_warnings}
      end)

    {results, all_warnings}
  end

  defp process_file(%{source: source, coverage: coverage, path: path} = file_stats) do
    source_lines = String.split(source, "\n")
    directives = directives_by_line(source)

    {new_coverage, warnings} =
      source_lines
      |> Enum.zip(coverage)
      |> Enum.with_index(1)
      |> Enum.reduce({[], :normal, []}, fn {{line, cov}, line_num}, {acc, state, warns} ->
        directive = Map.get(directives, line_num, classify_line(String.trim(line)))

        case {state, directive} do
          {:normal, :start} ->
            {[cov | acc], :ignoring, warns}

          {:normal, :stop} ->
            warning = "#{path}:#{line_num}: six:ignore:stop without matching start"
            {[cov | acc], :normal, [warning | warns]}

          {:normal, :next} ->
            {[cov | acc], :ignore_next, warns}

          {:normal, _} ->
            {[cov | acc], :normal, warns}

          {:ignoring, :stop} ->
            {[cov | acc], :normal, warns}

          {:ignoring, _} ->
            {[nil | acc], :ignoring, warns}

          {:ignore_next, :start} ->
            # The next line after :next is a start marker — ignore it and enter ignoring
            {[nil | acc], :ignoring, warns}

          {:ignore_next, _} ->
            {[nil | acc], :normal, warns}
        end
      end)
      |> then(fn {acc, state, warns} ->
        final_warns =
          if state == :ignoring do
            ["#{path}: unclosed six:ignore:start" | warns]
          else
            warns
          end

        {Enum.reverse(acc), Enum.reverse(final_warns)}
      end)

    {Six.Stats.recalculate(%{file_stats | coverage: new_coverage}), warnings}
  end

  @doc """
  Scans source for comment-based ignore directives and returns the ignored ranges.
  Used for reporting — does not modify coverage.
  Returns [{start_line, end_line, type}] where type is :block or :next.
  """
  def ignored_ranges(source) do
    directives = directives_by_line(source)

    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce({:normal, nil, []}, fn {line, line_num}, {state, block_start, acc} ->
      directive = Map.get(directives, line_num, classify_line(String.trim(line)))

      case {state, directive} do
        {:normal, :start} ->
          {:ignoring, line_num, acc}

        {:normal, :next} ->
          {:ignore_next, nil, acc}

        {:ignore_next, _} ->
          {:normal, nil, [{line_num, line_num, :next} | acc]}

        {:ignoring, :stop} ->
          {:normal, nil, [{block_start, line_num, :block} | acc]}

        {:ignoring, _} ->
          {:ignoring, block_start, acc}

        _ ->
          {state, block_start, acc}
      end
    end)
    |> elem(2)
    |> Enum.reverse()
  end

  defp classify_line(trimmed) do
    cond do
      Regex.match?(@directive_patterns.start, trimmed) -> :start
      Regex.match?(@directive_patterns.stop, trimmed) -> :stop
      Regex.match?(@directive_patterns.next, trimmed) -> :next
      true -> :code
    end
  end

  defp directives_by_line(source) do
    source_lines = String.split(source, "\n")

    case Code.string_to_quoted_with_comments(source, columns: true, token_metadata: true) do
      {:ok, _ast, comments} ->
        comments
        |> Enum.reduce(%{}, fn %{line: line, text: text, column: column}, acc ->
          if standalone_comment?(source_lines, line, column) do
            Map.put(acc, line, classify_line(text))
          else
            acc
          end
        end)

      {:error, _} ->
        fallback_directives_by_line(source)
    end
  end

  defp fallback_directives_by_line(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce(%{}, fn {line, line_num}, acc ->
      case classify_line(String.trim(line)) do
        :code -> acc
        directive -> Map.put(acc, line_num, directive)
      end
    end)
  end

  defp standalone_comment?(source_lines, line, column) do
    source_line = Enum.at(source_lines, line - 1, "")
    prefix = String.slice(source_line, 0, max(column - 1, 0))
    String.trim(prefix) == ""
  end
end
