defmodule Six.StatsTest do
  use ExUnit.Case

  alias Six.Stats

  test "summarize computes correct totals" do
    files = [
      %{
        path: "a.ex",
        source: "",
        coverage: [1, 0, nil],
        lines: 3,
        relevant: 2,
        covered: 1,
        missed: 1,
        percentage: 50.0
      },
      %{
        path: "b.ex",
        source: "",
        coverage: [1, 1, 1],
        lines: 3,
        relevant: 3,
        covered: 3,
        missed: 0,
        percentage: 100.0
      }
    ]

    summary = Stats.summarize(files)

    assert summary.total_lines == 6
    assert summary.total_relevant == 5
    assert summary.total_covered == 4
    assert summary.total_missed == 1
    assert summary.percentage == 80.0
  end

  test "summarize handles zero relevant lines" do
    files = [
      %{
        path: "a.ex",
        source: "",
        coverage: [nil, nil],
        lines: 2,
        relevant: 0,
        covered: 0,
        missed: 0,
        percentage: 100.0
      }
    ]

    summary = Stats.summarize(files)
    assert summary.percentage == 100.0
  end

  test "skip_files removes matching files with regex" do
    files = [
      %{
        path: "lib/app/real.ex",
        source: "",
        coverage: [],
        lines: 0,
        relevant: 0,
        covered: 0,
        missed: 0,
        percentage: 100.0
      },
      %{
        path: "lib/app/generated/proto.ex",
        source: "",
        coverage: [],
        lines: 0,
        relevant: 0,
        covered: 0,
        missed: 0,
        percentage: 100.0
      }
    ]

    result = Stats.skip_files(files, [~r/generated\//])
    assert length(result) == 1
    assert hd(result).path == "lib/app/real.ex"
  end

  test "skip_files removes matching files with string" do
    files = [
      %{
        path: "lib/app/real.ex",
        source: "",
        coverage: [],
        lines: 0,
        relevant: 0,
        covered: 0,
        missed: 0,
        percentage: 100.0
      },
      %{
        path: "lib/app/proto_pb.ex",
        source: "",
        coverage: [],
        lines: 0,
        relevant: 0,
        covered: 0,
        missed: 0,
        percentage: 100.0
      }
    ]

    result = Stats.skip_files(files, ["_pb.ex"])
    assert length(result) == 1
  end

  test "build creates file stats from cover data" do
    # Use a real module that's loaded and has a source file
    cover_data = %{
      Six.Config => [
        {{Six.Config, 1}, 0},
        {{Six.Config, 5}, 1},
        {{Six.Config, 10}, 3}
      ]
    }

    result = Stats.build(cover_data)
    assert length(result) == 1

    [file] = result
    assert file.path == "lib/six/config.ex"
    assert is_binary(file.source)
    assert is_list(file.coverage)
    assert file.lines > 0
  end

  test "build merges multiple modules from the same source file" do
    Code.compile_file("test/fixtures/multi_module.ex")

    cover_data = %{
      Six.Fixtures.MultiModuleFirst => [
        {{Six.Fixtures.MultiModuleFirst, 2}, 1},
        {{Six.Fixtures.MultiModuleFirst, 3}, 1}
      ],
      Six.Fixtures.MultiModuleSecond => [
        {{Six.Fixtures.MultiModuleSecond, 2}, 3},
        {{Six.Fixtures.MultiModuleSecond, 6}, 2}
      ]
    }

    result = Stats.build(cover_data)

    assert length(result) == 1

    [file] = result
    assert file.path == "test/fixtures/multi_module.ex"
    assert Enum.at(file.coverage, 1) == 3
    assert Enum.at(file.coverage, 5) == 2
  end

  test "build skips modules with no source path" do
    cover_data = %{
      NonExistentModule => [{{NonExistentModule, 1}, 0}]
    }

    result = Stats.build(cover_data)
    assert result == []
  end

  test "skip_files handles non-matching pattern types gracefully" do
    files = [
      %{
        path: "lib/app/real.ex",
        source: "",
        coverage: [],
        lines: 0,
        relevant: 0,
        covered: 0,
        missed: 0,
        percentage: 100.0
      }
    ]

    # Non-regex, non-string pattern (e.g. an atom) should not crash
    result = Stats.skip_files(files, [:not_a_pattern])
    assert length(result) == 1
  end

  test "recalculate updates stats from coverage array" do
    file_stats = %{
      path: "test.ex",
      source: "a\nb\nc",
      coverage: [1, nil, 0],
      lines: 3,
      relevant: 0,
      covered: 0,
      missed: 0,
      percentage: 0.0
    }

    result = Stats.recalculate(file_stats)
    assert result.relevant == 2
    assert result.covered == 1
    assert result.missed == 1
    assert result.percentage == 50.0
  end
end
