defmodule Six.IgnoreTest do
  use ExUnit.Case

  alias Six.Ignore

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

  test "ignores lines between start and stop markers" do
    source = """
    def foo, do: :ok
    # six:ignore:start
    def bar, do: :ignored
    def baz, do: :ignored
    # six:ignore:stop
    def qux, do: :ok\
    """

    coverage = [1, nil, 0, 0, nil, 1]

    {[result], warnings} = Ignore.run([make_file_stats(source, coverage)])

    assert warnings == []
    # foo
    assert Enum.at(result.coverage, 0) == 1
    # bar (ignored)
    assert Enum.at(result.coverage, 2) == nil
    # baz (ignored)
    assert Enum.at(result.coverage, 3) == nil
    # qux
    assert Enum.at(result.coverage, 5) == 1
  end

  test "ignores next line with :next marker" do
    source = """
    def foo, do: :ok
    # six:ignore:next
    def bar, do: :ignored
    def baz, do: :ok\
    """

    coverage = [1, nil, 0, 1]

    {[result], warnings} = Ignore.run([make_file_stats(source, coverage)])

    assert warnings == []
    # foo
    assert Enum.at(result.coverage, 0) == 1
    # bar (ignored)
    assert Enum.at(result.coverage, 2) == nil
    # baz (not ignored)
    assert Enum.at(result.coverage, 3) == 1
  end

  test "ignore_next followed by start marker enters ignoring mode" do
    source = """
    def foo, do: :ok
    # six:ignore:next
    # six:ignore:start
    def bar, do: :ignored
    # six:ignore:stop
    def baz, do: :ok\
    """

    coverage = [1, nil, nil, 0, nil, 1]

    {[result], warnings} = Ignore.run([make_file_stats(source, coverage)])

    assert warnings == []
    # foo
    assert Enum.at(result.coverage, 0) == 1
    # start marker (ignored by :next)
    assert Enum.at(result.coverage, 2) == nil
    # bar (ignored by start/stop block)
    assert Enum.at(result.coverage, 3) == nil
    # baz
    assert Enum.at(result.coverage, 5) == 1
  end

  test "warns on unclosed start block" do
    source = """
    def foo, do: :ok
    # six:ignore:start
    def bar, do: :ignored\
    """

    coverage = [1, nil, 0]

    {[_result], warnings} = Ignore.run([make_file_stats(source, coverage)])

    assert length(warnings) == 1
    assert hd(warnings) =~ "unclosed six:ignore:start"
  end

  test "ignored_ranges returns block ranges" do
    source = """
    def foo, do: :ok
    # six:ignore:start
    def bar, do: :ignored
    # six:ignore:stop
    def baz, do: :ok\
    """

    ranges = Ignore.ignored_ranges(source)
    assert [{2, 4, :block}] = ranges
  end

  test "ignored_ranges returns next-line ranges" do
    source = """
    def foo, do: :ok
    # six:ignore:next
    def bar, do: :ignored
    def baz, do: :ok\
    """

    ranges = Ignore.ignored_ranges(source)
    assert [{3, 3, :next}] = ranges
  end

  test "warns on stop without start" do
    source = """
    def foo, do: :ok
    # six:ignore:stop
    def bar, do: :ok\
    """

    coverage = [1, nil, 1]

    {[_result], warnings} = Ignore.run([make_file_stats(source, coverage)])

    assert length(warnings) == 1
    assert hd(warnings) =~ "six:ignore:stop without matching start"
  end

  test "does not treat heredoc or string contents as ignore directives" do
    source = """
    defmodule Foo do
      @doc \"\"\"
      # six:ignore:start
      \"\"\"
      def foo do
        "# six:ignore:next"
      end
    end
    """

    assert Ignore.ignored_ranges(source) == []
  end

  test "does not treat trailing inline comments as ignore directives" do
    source = """
    defmodule Foo do
      x = 1 # six:ignore:start
    end
    """

    assert Ignore.ignored_ranges(source) == []
  end

  test "falls back to line scanning for invalid source" do
    source = """
    defmodule Foo do
    # six:ignore:start
    """

    assert Ignore.ignored_ranges(source) == []

    coverage = [nil, nil]
    {[_result], warnings} = Ignore.run([make_file_stats(source, coverage)])
    assert warnings == ["test.ex: unclosed six:ignore:start"]
  end
end
