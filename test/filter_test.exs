defmodule Six.FilterTest do
  use ExUnit.Case

  alias Six.Filter

  defp make_file_stats(source, coverage) do
    lines = source |> String.split("\n") |> length()
    relevant = Enum.count(coverage, &(&1 != nil))
    covered = Enum.count(coverage, &(&1 != nil && &1 > 0))

    %{
      path: "test.ex",
      source: source,
      coverage: coverage,
      lines: lines,
      relevant: relevant,
      covered: covered,
      missed: relevant - covered,
      percentage: if(relevant > 0, do: Float.floor(covered / relevant * 100, 1), else: 100.0)
    }
  end

  test "nullifies defmodule lines" do
    source = """
    defmodule Foo do
      def bar do
        :ok
      end
    end\
    """

    coverage = [1, 1, 1, nil, 1]
    config = %{default_patterns: true, ignore_patterns: []}

    [result] = Filter.run([make_file_stats(source, coverage)], config)

    # defmodule
    assert Enum.at(result.coverage, 0) == nil
    # def bar
    assert Enum.at(result.coverage, 1) == 1
    # :ok
    assert Enum.at(result.coverage, 2) == 1
    # end
    assert Enum.at(result.coverage, 4) == nil
  end

  test "nullifies use, import, alias, require lines" do
    source = """
    defmodule Foo do
      use GenServer
      import Enum
      alias My.Module
      require Logger
      def bar, do: :ok
    end\
    """

    coverage = [1, 1, 1, 1, 1, 1, 1]
    config = %{default_patterns: true, ignore_patterns: []}

    [result] = Filter.run([make_file_stats(source, coverage)], config)

    # defmodule
    assert Enum.at(result.coverage, 0) == nil
    # use
    assert Enum.at(result.coverage, 1) == nil
    # import
    assert Enum.at(result.coverage, 2) == nil
    # alias
    assert Enum.at(result.coverage, 3) == nil
    # require
    assert Enum.at(result.coverage, 4) == nil
    # def bar
    assert Enum.at(result.coverage, 5) == 1
  end

  test "respects default_patterns: false" do
    source = """
    defmodule Foo do
      def bar, do: :ok
    end\
    """

    coverage = [1, 1, 1]
    config = %{default_patterns: false, ignore_patterns: []}

    [result] = Filter.run([make_file_stats(source, coverage)], config)

    # defmodule should NOT be filtered with defaults disabled
    assert Enum.at(result.coverage, 0) == 1
  end

  test "applies user patterns" do
    source = """
    defmodule Foo do
      @type t :: term()
      def bar, do: :ok
    end\
    """

    coverage = [1, 1, 1, 1]
    config = %{default_patterns: true, ignore_patterns: [~r/^\s*@type\s/]}

    [result] = Filter.run([make_file_stats(source, coverage)], config)

    # @type
    assert Enum.at(result.coverage, 1) == nil
    # def bar
    assert Enum.at(result.coverage, 2) == 1
  end

  test "compile_patterns merges defaults and user patterns" do
    config = %{default_patterns: true, ignore_patterns: [~r/custom/]}
    patterns = Filter.compile_patterns(config)

    # Should include default patterns plus the custom one
    assert length(patterns) > 1
    assert Enum.any?(patterns, &Regex.match?(&1, "custom stuff"))
  end

  test "compile_patterns handles string patterns" do
    config = %{default_patterns: false, ignore_patterns: ["^\\s*@type\\s"]}
    patterns = Filter.compile_patterns(config)

    assert length(patterns) == 1
    assert Regex.match?(hd(patterns), "  @type t :: term()")
  end

  test "compile_patterns falls back to defaults for non-matching input" do
    patterns = Filter.compile_patterns(:not_a_config)
    assert length(patterns) > 0
  end
end
