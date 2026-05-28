defmodule Six.HeatmapTest do
  use ExUnit.Case

  alias Six.Heatmap

  test "bucket maps counts to decade buckets" do
    assert Heatmap.bucket(nil) == nil
    assert Heatmap.bucket(0) == :cold
    assert Heatmap.bucket(1) == 1
    assert Heatmap.bucket(9) == 2
    assert Heatmap.bucket(10) == 3
    assert Heatmap.bucket(99) == 3
    assert Heatmap.bucket(100) == 4
    assert Heatmap.bucket(999) == 4
    assert Heatmap.bucket(1000) == 5
    assert Heatmap.bucket(50_000) == 5
  end

  test "cold_lines counts lines hit exactly once" do
    assert Heatmap.cold_lines([nil, 0, 1, 1, 2, 100]) == 2
    assert Heatmap.cold_lines([nil, nil]) == 0
  end

  test "max_hits returns the largest count, ignoring nil" do
    assert Heatmap.max_hits([nil, 0, 12, 4, nil]) == 12
    assert Heatmap.max_hits([nil, nil]) == 0
    assert Heatmap.max_hits([]) == 0
  end
end
