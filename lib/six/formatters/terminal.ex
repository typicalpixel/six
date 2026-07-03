defmodule Six.Formatters.Terminal do
  @moduledoc false
  @behaviour Six.Formatter

  @impl true
  def format(summary, opts \\ []) do
    detail = Keyword.get(opts, :detail, false)
    filter = Keyword.get(opts, :filter, nil)
    threshold = Keyword.get(opts, :threshold, 90)

    {uncovered, covered} = Enum.split_with(summary.files, fn f -> f.missed > 0 end)

    path_width = max_path_width(uncovered)

    IO.puts("")
    print_separator()

    if uncovered != [] do
      print_header(path_width)
      print_files(uncovered, threshold, path_width)
    end

    print_covered_count(length(covered))
    print_total(summary.percentage, threshold)
    print_separator()

    if detail do
      print_detail(summary.files, filter)
    end

    :ok
  end

  defp print_separator do
    IO.puts("----------------")
  end

  defp print_header(path_width) do
    IO.puts(
      pad_right("COV", 7) <>
        pad_right("FILE", path_width) <>
        pad_left("LINES", 8) <>
        pad_left("RELEVANT", 10) <>
        pad_left("MISSED", 8)
    )
  end

  defp print_files(files, threshold, path_width) do
    sorted = Enum.sort_by(files, & &1.percentage)

    Enum.each(sorted, fn file ->
      cov_str = format_percentage(file.percentage)
      color = color_for(file.percentage, threshold)

      line =
        pad_right(cov_str, 7) <>
          pad_right(file.path, path_width) <>
          pad_left(to_string(file.lines), 8) <>
          pad_left(to_string(file.relevant), 10) <>
          pad_left(to_string(file.missed), 8)

      # six:ignore:start
      if IO.ANSI.enabled?() do
        IO.puts(color <> line <> IO.ANSI.reset())
      else
        IO.puts(line)
      end

      # six:ignore:stop
    end)
  end

  defp print_covered_count(0), do: :ok

  defp print_covered_count(count) do
    label = if count == 1, do: "file", else: "files"
    IO.puts("#{count} #{label} fully covered (not shown)")
  end

  defp print_total(percentage, threshold) do
    color = color_for(percentage, threshold)
    line = "[TOTAL] #{format_percentage(percentage)}"

    # six:ignore:start
    if IO.ANSI.enabled?() do
      IO.puts(color <> line <> IO.ANSI.reset())
    else
      IO.puts(line)
    end

    # six:ignore:stop
  end

  defp print_detail(files, filter) do
    files
    |> maybe_filter(filter)
    |> Enum.sort_by(& &1.percentage)
    |> Enum.each(fn file ->
      IO.puts("\n#{file.path}")
      IO.puts(String.duplicate("-", String.length(file.path)))

      source_lines = String.split(file.source, "\n")

      source_lines
      |> Enum.zip(file.coverage)
      |> Enum.with_index(1)
      |> Enum.each(fn {{line, cov}, line_num} ->
        prefix = String.pad_leading(to_string(line_num), 5) <> " "

        {marker, color} =
          case cov do
            nil -> {" ", IO.ANSI.default_color()}
            0 -> {"×", IO.ANSI.red()}
            _ -> {"✓", IO.ANSI.green()}
          end

        # six:ignore:start
        if IO.ANSI.enabled?() do
          IO.puts(color <> prefix <> marker <> " " <> line <> IO.ANSI.reset())
        else
          IO.puts(prefix <> marker <> " " <> line)
        end

        # six:ignore:stop
      end)
    end)
  end

  defp max_path_width(files) do
    min_width = String.length("FILE")

    files
    |> Enum.map(fn f -> String.length(f.path) end)
    |> Enum.max(fn -> min_width end)
    |> max(min_width)
    |> Kernel.+(2)
  end

  defp maybe_filter(files, nil), do: files

  defp maybe_filter(files, pattern) do
    Enum.filter(files, &String.contains?(&1.path, pattern))
  end

  defp format_percentage(pct) do
    :erlang.float_to_binary(pct, decimals: 1) <> "%"
  end

  defp color_for(pct, threshold) when pct >= threshold, do: IO.ANSI.green()
  defp color_for(_, _), do: IO.ANSI.red()

  defp pad_right(str, width), do: String.pad_trailing(str, width)
  defp pad_left(str, width), do: String.pad_leading(str, width)
end
