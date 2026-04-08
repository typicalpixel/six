defmodule Six.Report do
  @moduledoc false

  def run(opts \\ []) do
    config =
      Six.Config.read()
      |> Six.Config.merge_with_opts(opts)

    summary = build_summary(config)

    formatter_opts = [
      output_dir: config.output_dir,
      detail: config.detail,
      filter: config.filter,
      threshold: config.threshold
    ]

    Enum.each(config.formatters, fn formatter ->
      formatter.format(summary, formatter_opts)
    end)

    if config.track_ignores, do: Six.TrackIgnores.write(summary, config)

    enforce_minimum_coverage!(summary, config.minimum_coverage)

    summary
  end

  defp build_summary(config) do
    file_stats =
      Six.Cover.analyze_all()
      |> Six.Stats.build()
      |> Six.Stats.skip_files(config.skip_files)
      |> Six.Filter.run(config)
      |> apply_comment_ignores()
      |> Six.Ignore.Functions.run()

    Six.Stats.summarize(file_stats)
  end

  defp apply_comment_ignores(file_stats) do
    {file_stats, warnings} = Six.Ignore.run(file_stats)
    Enum.each(warnings, &IO.warn/1)
    file_stats
  end

  defp enforce_minimum_coverage!(_summary, 0), do: :ok

  defp enforce_minimum_coverage!(summary, minimum_coverage) do
    if summary.percentage < minimum_coverage do
      Mix.raise(
        "Coverage (#{Float.floor(summary.percentage, 1)}%) is below the minimum threshold (#{minimum_coverage}%)"
      )
    end

    :ok
  end
end
