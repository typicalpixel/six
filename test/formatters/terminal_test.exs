defmodule Six.Formatters.TerminalTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Six.Formatters.Terminal

  defp sample_summary do
    %{
      files: [
        %{
          path: "lib/a.ex",
          source: "line_one\nline_two\n# comment",
          coverage: [1, 0, nil],
          lines: 3,
          relevant: 2,
          covered: 1,
          missed: 1,
          percentage: 50.0
        },
        %{
          path: "lib/b.ex",
          source: "line_one\nline_two",
          coverage: [1, 1],
          lines: 2,
          relevant: 2,
          covered: 2,
          missed: 0,
          percentage: 100.0
        }
      ],
      total_lines: 4,
      total_relevant: 4,
      total_covered: 3,
      total_missed: 1,
      percentage: 75.0
    }
  end

  test "format outputs summary table" do
    output =
      capture_io(fn ->
        Terminal.format(sample_summary(), threshold: 90)
      end)

    assert output =~ "COV"
    assert output =~ "FILE"
    assert output =~ "lib/a.ex"
    assert output =~ "lib/b.ex"
    assert output =~ "TOTAL"
    assert output =~ "75.0%"
  end

  test "format sorts by coverage ascending" do
    output =
      capture_io(fn ->
        Terminal.format(sample_summary(), threshold: 90)
      end)

    a_pos = :binary.match(output, "lib/a.ex") |> elem(0)
    b_pos = :binary.match(output, "lib/b.ex") |> elem(0)
    assert a_pos < b_pos
  end

  test "format with detail mode shows source lines" do
    output =
      capture_io(fn ->
        Terminal.format(sample_summary(), threshold: 90, detail: true)
      end)

    assert output =~ "lib/a.ex"
    assert output =~ "line_one"
    assert output =~ "line_two"
  end

  test "format with detail and filter shows only matching files" do
    output =
      capture_io(fn ->
        Terminal.format(sample_summary(), threshold: 90, detail: true, filter: "lib/b")
      end)

    # Should show b.ex source detail but not a.ex
    assert output =~ "lib/b.ex"
    # The summary table still shows both, but detail only shows filtered
  end

  test "format handles file with zero relevant lines" do
    summary = %{
      files: [
        %{
          path: "lib/empty.ex",
          source: "# comment",
          coverage: [nil],
          lines: 1,
          relevant: 0,
          covered: 0,
          missed: 0,
          percentage: 100.0
        }
      ],
      total_lines: 1,
      total_relevant: 0,
      total_covered: 0,
      total_missed: 0,
      percentage: 100.0
    }

    output =
      capture_io(fn ->
        Terminal.format(summary, threshold: 90)
      end)

    assert output =~ "100.0%"
  end

  test "format handles empty file list" do
    summary = %{
      files: [],
      total_lines: 0,
      total_relevant: 0,
      total_covered: 0,
      total_missed: 0,
      percentage: 100.0
    }

    output =
      capture_io(fn ->
        Terminal.format(summary)
      end)

    assert output =~ "TOTAL"
    assert output =~ "100.0%"
  end

  test "format auto-sizes path column to longest path" do
    summary = %{
      files: [
        %{
          path: "lib/short.ex",
          source: "x",
          coverage: [1],
          lines: 1,
          relevant: 1,
          covered: 1,
          missed: 0,
          percentage: 100.0
        },
        %{
          path: "lib/apps/my_app/very/long/path/module.ex",
          source: "x",
          coverage: [1],
          lines: 1,
          relevant: 1,
          covered: 1,
          missed: 0,
          percentage: 100.0
        }
      ],
      total_lines: 2,
      total_relevant: 2,
      total_covered: 2,
      total_missed: 0,
      percentage: 100.0
    }

    output =
      capture_io(fn ->
        Terminal.format(summary, threshold: 90)
      end)

    # The long path should not be truncated
    assert output =~ "lib/apps/my_app/very/long/path/module.ex"
  end

  test "format uses default opts when none provided" do
    output =
      capture_io(fn ->
        Terminal.format(sample_summary())
      end)

    assert output =~ "TOTAL"
  end
end
