defmodule Six.Ignore.FunctionsTest do
  use ExUnit.Case

  alias Six.Ignore.Functions

  test "find_ignored_ranges finds tagged functions" do
    source = """
    defmodule Foo do
      def normal, do: :ok

      @six :ignore
      def excluded do
        :stuff
      end

      def also_normal, do: :ok
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 1
    [{start_line, end_line}] = ranges
    assert start_line == 5
    assert end_line >= 7
  end

  test "find_ignored_ranges handles one-liners" do
    source = """
    defmodule Foo do
      @six :ignore
      def excluded, do: :bar

      def normal, do: :ok
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 1
    [{start_line, _end_line}] = ranges
    assert start_line == 3
  end

  test "find_ignored_ranges handles multiple tagged functions" do
    source = """
    defmodule Foo do
      @six :ignore
      def first do
        :a
      end

      def normal, do: :ok

      @six :ignore
      def second do
        :b
      end
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 2
  end

  test "find_ignored_ranges skips @doc between @six and def" do
    source = """
    defmodule Foo do
      @six :ignore
      @doc "some doc"
      def excluded do
        :stuff
      end
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 1
    [{start_line, _}] = ranges
    # def line, not @six or @doc line
    assert start_line == 4
  end

  test "find_ignored_ranges returns empty when no @six present" do
    source = """
    defmodule Foo do
      def normal, do: :ok
    end
    """

    assert Functions.find_ignored_ranges(source) == []
  end

  test "find_ignored_ranges falls back to string parsing on invalid source" do
    source = """
    defmodule Foo do
      @six :ignore
      def broken(x), do: x
    """

    assert Functions.find_ignored_ranges(source) == [{3, 3}]
  end

  test "fallback parsing assigns unknown names to malformed definitions" do
    source = """
    defmodule Foo do
      @six :ignore
      def (
    """

    [result] = Functions.ignored_functions(source)
    assert result.function == "def unknown"
  end

  test "run nullifies coverage for tagged functions" do
    source = """
    defmodule Foo do
      def normal do
        :ok
      end

      @six :ignore
      def excluded do
        :stuff
        :more
      end

      def also_normal do
        :ok
      end
    end
    """

    coverage = [nil, 1, 1, nil, nil, nil, 0, 0, 0, nil, nil, 1, 1, nil, nil]
    lines = source |> String.split("\n") |> length()
    relevant = Enum.count(coverage, &(&1 != nil))
    covered = Enum.count(coverage, &(&1 != nil && &1 > 0))

    file_stats = %{
      path: "test.ex",
      source: source,
      coverage: coverage,
      lines: lines,
      relevant: relevant,
      covered: covered,
      missed: relevant - covered,
      percentage: Float.floor(covered / relevant * 100, 1)
    }

    [result] = Functions.run([file_stats])

    # The excluded function lines (7, 8, 9) should be nil
    assert Enum.at(result.coverage, 6) == nil
    assert Enum.at(result.coverage, 7) == nil
    assert Enum.at(result.coverage, 8) == nil

    # Normal function lines should remain
    assert Enum.at(result.coverage, 1) == 1
    assert Enum.at(result.coverage, 2) == 1
    assert Enum.at(result.coverage, 11) == 1
  end

  test "run returns file unchanged when no @six present" do
    source = """
    defmodule Foo do
      def normal, do: :ok
    end
    """

    coverage = [nil, 1, nil]

    file_stats = %{
      path: "test.ex",
      source: source,
      coverage: coverage,
      lines: 3,
      relevant: 1,
      covered: 1,
      missed: 0,
      percentage: 100.0
    }

    [result] = Functions.run([file_stats])
    assert result.coverage == coverage
  end

  test "find_ignored_ranges handles nested modules" do
    source = """
    defmodule Outer do
      defmodule Inner do
        @six :ignore
        def excluded, do: :nope
      end
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 1
  end

  test "find_ignored_ranges handles defp and defmacro" do
    source = """
    defmodule Foo do
      @six :ignore
      defp private_func do
        :private
      end

      @six :ignore
      defmacro my_macro(x) do
        quote do: unquote(x)
      end
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 2
  end

  test "functions handles guarded definitions" do
    source = """
    defmodule Foo do
      def guarded(value) when is_atom(value), do: value
    end
    """

    [function] = Functions.functions(source)
    assert function.function == "def guarded"
    assert function.ignored? == false
  end

  test "functions falls back to generic function label for non-atom heads" do
    source = """
    defmodule Foo do
      def unquote(name)(x), do: x
    end
    """

    [function] = Functions.functions(source)
    assert function.function == "def"
    assert function.ignored? == false
  end

  test "find_function_end scans for matching end" do
    lines = [
      "  def foo do",
      "    if true do",
      "      :nested",
      "    end",
      "  end",
      "  def bar, do: :ok"
    ]

    end_line = Functions.find_function_end(lines, 1)
    assert end_line == 5
  end

  test "find_function_end ignores one-line do clauses inside a function" do
    lines = [
      "  def foo(value) do",
      "    if value, do: :ok",
      "    :done",
      "  end"
    ]

    end_line = Functions.find_function_end(lines, 1)
    assert end_line == 4
  end

  test "find_function_end ignores comments and strings with do/end" do
    lines = [
      "  def foo do",
      ~s|    text = "do end"|,
      "    # end",
      "    :ok",
      "  end"
    ]

    end_line = Functions.find_function_end(lines, 1)
    assert end_line == 5
  end

  test "find_function_end falls back to the start line when no block end is found" do
    lines = ["  def foo(x), x + 1"]

    end_line = Functions.find_function_end(lines, 1)
    assert end_line == 1
  end

  test "find_ignored_ranges handles @impl between @six and def" do
    source = """
    defmodule Foo do
      @six :ignore
      @impl true
      def callback_func do
        :stuff
      end
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 1
    [{start_line, _}] = ranges
    assert start_line == 4
  end

  test "find_ignored_ranges drops @six :ignore not followed by def" do
    source = """
    defmodule Foo do
      @six :ignore
      x = 1 + 2
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert ranges == []
  end

  test "ignored_functions returns function names with ranges" do
    source = """
    defmodule Foo do
      @six :ignore
      def excluded_func do
        :stuff
      end

      @six :ignore
      defp private_helper, do: :ok
    end
    """

    results = Functions.ignored_functions(source)
    assert length(results) == 2

    [first, second] = results
    assert first.function == "def excluded_func"
    assert second.function == "defp private_helper"
  end

  test "find_ignored_ranges handles single-expression module body" do
    source = """
    defmodule Foo do
      @six :ignore
      def only_func, do: :ok
    end
    """

    ranges = Functions.find_ignored_ranges(source)
    assert length(ranges) == 1
  end

  test "functions returns definitions with source ranges" do
    source = """
    defmodule Foo do
      def visible do
        if true, do: :ok
        :done
      end
    end
    """

    [function] = Functions.functions(source)
    assert function.function == "def visible"
    assert function.start_line == 2
    assert function.end_line == 5
    assert function.ignored? == false
  end

  test "functions returns empty for nil module body" do
    assert Functions.functions("defmodule Foo, do: nil") == []
  end
end
