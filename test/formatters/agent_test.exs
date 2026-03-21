defmodule Six.Formatters.AgentTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Six.Formatters.Agent

  defp sample_summary do
    source = """
    defmodule Foo do
      def covered_func do
        :ok
      end

      def uncovered_func do
        :not_called
      end

      def partial_func(x) do
        case x do
          :ok -> :handled
          :error -> :failed
        end
      end
    end
    """

    %{
      files: [
        %{
          path: "lib/foo.ex",
          source: source,
          coverage: [nil, 5, 5, nil, nil, 0, 0, nil, nil, 3, nil, 3, 0, nil, nil, nil],
          lines: 16,
          relevant: 6,
          covered: 3,
          missed: 3,
          percentage: 50.0
        }
      ],
      total_lines: 16,
      total_relevant: 6,
      total_covered: 3,
      total_missed: 3,
      percentage: 50.0
    }
  end

  test "render produces valid markdown" do
    content = Agent.render(sample_summary(), threshold: 90)

    assert content =~ "# Six Coverage Report"
    assert content =~ "Total: 50.0%"
    assert content =~ "lib/foo.ex"
    assert content =~ "Uncovered files"
  end

  test "render includes function attribution" do
    content = Agent.render(sample_summary(), threshold: 90)
    assert content =~ "uncovered_func" or content =~ "partial_func"
  end

  test "render includes source snippets" do
    content = Agent.render(sample_summary(), threshold: 90)
    assert content =~ "```elixir"
  end

  test "render shows threshold status" do
    content = Agent.render(sample_summary(), threshold: 90)
    assert content =~ "❌"

    passing_summary = %{sample_summary() | percentage: 95.0}
    content2 = Agent.render(passing_summary, threshold: 90)
    assert content2 =~ "✅"
  end

  test "render lists fully covered files" do
    summary = %{
      files: [
        %{
          path: "lib/good.ex",
          source: "x",
          coverage: [1],
          lines: 1,
          relevant: 1,
          covered: 1,
          missed: 0,
          percentage: 100.0
        }
      ],
      total_lines: 1,
      total_relevant: 1,
      total_covered: 1,
      total_missed: 0,
      percentage: 100.0
    }

    content = Agent.render(summary, threshold: 90)
    assert content =~ "Fully covered files"
    assert content =~ "lib/good.ex"
    assert content =~ "100.0%"
  end

  test "render with no uncovered files" do
    summary = %{
      files: [
        %{
          path: "lib/good.ex",
          source: "x",
          coverage: [1],
          lines: 1,
          relevant: 1,
          covered: 1,
          missed: 0,
          percentage: 100.0
        }
      ],
      total_lines: 1,
      total_relevant: 1,
      total_covered: 1,
      total_missed: 0,
      percentage: 100.0
    }

    content = Agent.render(summary, threshold: 90)
    refute content =~ "Uncovered files"
  end

  test "group_missed_lines groups contiguous zeros" do
    coverage = [1, 0, 0, 0, nil, 1, 0, 1]
    groups = Agent.group_missed_lines(coverage)
    assert groups == [{2, 4}, {7, 7}]
  end

  test "group_missed_lines handles empty" do
    assert Agent.group_missed_lines([1, 1, nil]) == []
  end

  test "attribute_to_function finds enclosing function" do
    lines = [
      "defmodule Foo do",
      "  def my_func(x) do",
      "    case x do",
      "      :ok -> :yes",
      "      :error -> :no",
      "    end",
      "  end",
      "end"
    ]

    assert Agent.attribute_to_function(lines, {5, 5}) == "my_func"
    assert Agent.attribute_to_function(lines, {4, 4}) == "my_func"
  end

  test "attribute_to_function returns nil when no function found" do
    lines = ["# just a comment", "# another comment"]
    assert Agent.attribute_to_function(lines, {1, 1}) == nil
  end

  test "detect_branch_context identifies error branches" do
    lines = [
      "  def foo(x) do",
      "    case x do",
      "      {:ok, val} -> val",
      "      {:error, reason} -> reason",
      "    end",
      "  end"
    ]

    assert Agent.detect_branch_context(lines, {4, 4}) =~ "error"
  end

  test "detect_branch_context identifies ok branches" do
    lines = ["  {:ok, val} -> val"]
    assert Agent.detect_branch_context(lines, {1, 1}) =~ "ok"
  end

  test "detect_branch_context identifies :error atom" do
    lines = ["  :error -> handle_error()"]
    assert Agent.detect_branch_context(lines, {1, 1}) =~ ":error"
  end

  test "detect_branch_context identifies else branches" do
    lines = ["  else", "    :default"]
    assert Agent.detect_branch_context(lines, {1, 1}) =~ "else"
  end

  test "detect_branch_context identifies false branches" do
    lines = ["  false -> :nope"]
    assert Agent.detect_branch_context(lines, {1, 1}) =~ "false"
  end

  test "detect_branch_context identifies nil branches" do
    lines = ["  nil -> :nothing"]
    assert Agent.detect_branch_context(lines, {1, 1}) =~ "nil"
  end

  test "detect_branch_context identifies arrow pattern branches" do
    lines = ["  :timeout ->", "    handle_timeout()"]
    result = Agent.detect_branch_context(lines, {1, 1})
    assert result =~ ":timeout"
  end

  test "detect_branch_context returns nil for plain code" do
    lines = ["  x = compute()", "  process(x)"]
    assert Agent.detect_branch_context(lines, {1, 1}) == nil
  end

  test "extract_source_block truncates long blocks" do
    lines = for i <- 1..20, do: "  line #{i}"
    result = Agent.extract_source_block(lines, 1, 20)

    assert length(result) < 20
    assert Enum.any?(result, &String.contains?(&1, "more lines"))
  end

  test "extract_source_block returns short blocks as-is" do
    lines = ["  line 1", "  line 2", "  line 3"]
    result = Agent.extract_source_block(lines, 1, 3)
    assert result == lines
  end

  test "output_path returns default path" do
    assert Agent.output_path([]) == ".six/coverage.md"
  end

  test "output_path respects output_dir option" do
    assert Agent.output_path(output_dir: "my_dir") == "my_dir/coverage.md"
  end

  test "render with partial coverage and no branch context" do
    # Function is partially covered (not entirely missed), no branch keywords
    source = """
    defmodule Foo do
      def my_func do
        a = 1
        b = 2
        a + b
      end
    end
    """

    summary = %{
      files: [
        %{
          path: "lib/foo.ex",
          source: source,
          coverage: [nil, 1, 1, 0, 0, nil, nil],
          lines: 7,
          relevant: 4,
          covered: 2,
          missed: 2,
          percentage: 50.0
        }
      ],
      total_lines: 7,
      total_relevant: 4,
      total_covered: 2,
      total_missed: 2,
      percentage: 50.0
    }

    content = Agent.render(summary, threshold: 90)
    assert content =~ "my_func"
    assert content =~ "Lines"
  end

  test "render handles fallback function labels" do
    source = """
    defmodule Foo do
      def unquote(name)(x), do: x
    end
    """

    summary = %{
      files: [
        %{
          path: "lib/foo.ex",
          source: source,
          coverage: [nil, 0, nil],
          lines: 3,
          relevant: 1,
          covered: 0,
          missed: 1,
          percentage: 0.0
        }
      ],
      total_lines: 3,
      total_relevant: 1,
      total_covered: 0,
      total_missed: 1,
      percentage: 0.0
    }

    content = Agent.render(summary, threshold: 90)
    assert content =~ "`def`"
  end

  test "format writes file to disk" do
    dir = System.tmp_dir!() |> Path.join("six_agent_test_#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)

    summary = %{
      files: [],
      total_lines: 0,
      total_relevant: 0,
      total_covered: 0,
      total_missed: 0,
      percentage: 100.0
    }

    capture_io(fn ->
      Agent.format(summary, output_dir: dir)
    end)

    assert File.exists?(Path.join(dir, "coverage.md"))
    File.rm_rf!(dir)
  end

  test "render includes ignored section when files have ignores" do
    source = """
    defmodule Foo do
      @six :ignore
      def excluded do
        :stuff
      end

      # six:ignore:next
      def also_excluded, do: :ok

      def covered do
        :ok
      end
    end
    """

    summary = %{
      files: [
        %{
          path: "lib/foo.ex",
          source: source,
          coverage: [nil, nil, nil, nil, nil, nil, nil, nil, nil, 1, 1, nil, nil, nil],
          lines: 14,
          relevant: 2,
          covered: 2,
          missed: 0,
          percentage: 100.0
        }
      ],
      total_lines: 14,
      total_relevant: 2,
      total_covered: 2,
      total_missed: 0,
      percentage: 100.0
    }

    content = Agent.render(summary, threshold: 90)
    assert content =~ "## Ignored"
    assert content =~ "@six :ignore"
    assert content =~ "def excluded"
    assert content =~ "six:ignore:next"
  end

  test "render omits ignored section when no ignores present" do
    source = """
    defmodule Foo do
      def covered, do: :ok
    end
    """

    summary = %{
      files: [
        %{
          path: "lib/foo.ex",
          source: source,
          coverage: [nil, 1, nil],
          lines: 3,
          relevant: 1,
          covered: 1,
          missed: 0,
          percentage: 100.0
        }
      ],
      total_lines: 3,
      total_relevant: 1,
      total_covered: 1,
      total_missed: 0,
      percentage: 100.0
    }

    content = Agent.render(summary, threshold: 90)
    refute content =~ "## Ignored"
  end

  test "format with default opts writes to .six/" do
    summary = %{
      files: [],
      total_lines: 0,
      total_relevant: 0,
      total_covered: 0,
      total_missed: 0,
      percentage: 100.0
    }

    capture_io(fn ->
      Agent.format(summary)
    end)

    assert File.exists?(".six/coverage.md")
  end
end
