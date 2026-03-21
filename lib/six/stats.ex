defmodule Six.Stats do
  @moduledoc false

  @type line_coverage :: nil | non_neg_integer()

  @type file_stats :: %{
          path: String.t(),
          source: String.t(),
          coverage: [line_coverage()],
          lines: non_neg_integer(),
          relevant: non_neg_integer(),
          covered: non_neg_integer(),
          missed: non_neg_integer(),
          percentage: float()
        }

  @type summary :: %{
          files: [file_stats()],
          total_lines: non_neg_integer(),
          total_relevant: non_neg_integer(),
          total_covered: non_neg_integer(),
          total_missed: non_neg_integer(),
          percentage: float()
        }

  @doc """
  Builds per-file stats from raw cover data.
  cover_data is a map of %{module => [{{module, line}, count}]}.
  """
  def build(cover_data) do
    cover_data
    |> Enum.reduce(%{}, fn {module, results}, acc ->
      case Six.Cover.module_path(module) do
        nil ->
          acc

        path ->
          module_cover_map = results_to_cover_map(results)

          Map.update(acc, path, module_cover_map, fn cover_map ->
            Map.merge(cover_map, module_cover_map, fn _line, existing, current ->
              max(existing, current)
            end)
          end)
      end
    end)
    |> Enum.map(fn {path, cover_map} -> build_file_stats(path, cover_map) end)
    |> Enum.sort_by(& &1.path)
  end

  defp build_file_stats(path, cover_map) do
    source = File.read!(path)
    source_lines = String.split(source, "\n")
    total_lines = length(source_lines)

    coverage =
      for i <- 1..max(total_lines, 1) do
        Map.get(cover_map, i, nil)
      end

    relevant = Enum.count(coverage, &(&1 != nil))
    covered = Enum.count(coverage, &(&1 != nil && &1 > 0))
    missed = relevant - covered

    %{
      path: path,
      source: source,
      coverage: coverage,
      lines: total_lines,
      relevant: relevant,
      covered: covered,
      missed: missed,
      percentage: calc_percentage(covered, relevant)
    }
  end

  defp results_to_cover_map(results) do
    Map.new(results, fn {{_mod, line}, count} -> {line, count} end)
  end

  @doc """
  Aggregates file stats into a summary.
  """
  def summarize(file_stats_list) do
    total_lines = Enum.sum(Enum.map(file_stats_list, & &1.lines))
    total_relevant = Enum.sum(Enum.map(file_stats_list, & &1.relevant))
    total_covered = Enum.sum(Enum.map(file_stats_list, & &1.covered))
    total_missed = total_relevant - total_covered

    %{
      files: file_stats_list,
      total_lines: total_lines,
      total_relevant: total_relevant,
      total_covered: total_covered,
      total_missed: total_missed,
      percentage: calc_percentage(total_covered, total_relevant)
    }
  end

  @doc """
  Removes files whose paths match any of the given patterns.
  """
  def skip_files(file_stats_list, patterns) when is_list(patterns) do
    Enum.reject(file_stats_list, fn %{path: path} ->
      Enum.any?(patterns, fn pattern ->
        cond do
          is_struct(pattern, Regex) -> Regex.match?(pattern, path)
          is_binary(pattern) -> String.contains?(path, pattern)
          true -> false
        end
      end)
    end)
  end

  @doc """
  Recalculates relevant/covered/missed/percentage for a file_stats
  based on the current coverage array. Used after filtering nullifies lines.
  """
  def recalculate(%{coverage: coverage} = file_stats) do
    relevant = Enum.count(coverage, &(&1 != nil))
    covered = Enum.count(coverage, &(&1 != nil && &1 > 0))
    missed = relevant - covered

    %{
      file_stats
      | relevant: relevant,
        covered: covered,
        missed: missed,
        percentage: calc_percentage(covered, relevant)
    }
  end

  defp calc_percentage(_covered, 0), do: 100.0

  defp calc_percentage(covered, relevant) do
    Float.floor(covered / relevant * 100, 1)
  end
end
