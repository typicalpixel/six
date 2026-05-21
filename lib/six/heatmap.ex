defmodule Six.Heatmap do
  @moduledoc false

  # Maps a per-line hit count to a heat bucket. Buckets are fixed
  # order-of-magnitude decades so they're comparable across modules:
  #
  #   nil       uninstrumented (filtered or non-code)
  #   :cold     instrumented but never hit (×0)
  #   1         ×1            (covered, but barely — a "weak spot")
  #   2         ×2–9
  #   3         ×10–99
  #   4         ×100–999
  #   5         ×1000+        (hottest)

  @type bucket :: nil | :cold | 1..5

  @doc """
  Returns the heat bucket for a single line's hit count.
  """
  @spec bucket(nil | non_neg_integer()) :: bucket()
  def bucket(nil), do: nil
  def bucket(0), do: :cold
  def bucket(1), do: 1
  def bucket(n) when is_integer(n) and n < 10, do: 2
  def bucket(n) when is_integer(n) and n < 100, do: 3
  def bucket(n) when is_integer(n) and n < 1000, do: 4
  def bucket(n) when is_integer(n), do: 5

  @doc """
  Number of "weak-spot" lines — instrumented lines hit exactly once.
  """
  @spec cold_lines([nil | non_neg_integer()]) :: non_neg_integer()
  def cold_lines(coverage) do
    Enum.count(coverage, &(&1 == 1))
  end

  @doc """
  The largest hit count across a coverage array (0 when none).
  """
  @spec max_hits([nil | non_neg_integer()]) :: non_neg_integer()
  def max_hits(coverage) do
    coverage
    |> Enum.reduce(0, fn
      n, acc when is_integer(n) and n > acc -> n
      _, acc -> acc
    end)
  end
end
