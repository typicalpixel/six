defmodule Six.Formatters.HTMLTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Six.Formatters.HTML

  defp mkfile(path, source, coverage, opts \\ []) do
    relevant = Enum.count(coverage, &(&1 != nil))
    covered = Enum.count(coverage, &(&1 != nil and &1 > 0))

    %{
      path: path,
      source: source,
      coverage: coverage,
      function_calls: Keyword.get(opts, :fc, %{}),
      lines: length(String.split(source, "\n")),
      relevant: relevant,
      covered: covered,
      missed: relevant - covered,
      cold_lines: Enum.count(coverage, &(&1 == 1)),
      max_hits: Keyword.get(opts, :max, Six.Heatmap.max_hits(coverage)),
      percentage: Keyword.get(opts, :pct, pct(covered, relevant))
    }
  end

  defp pct(_covered, 0), do: 100.0
  defp pct(covered, relevant), do: Float.floor(covered / relevant * 100, 1)

  defp mksummary(files) do
    %{
      files: files,
      total_lines: Enum.sum(Enum.map(files, & &1.lines)),
      total_relevant: Enum.sum(Enum.map(files, & &1.relevant)),
      total_covered: Enum.sum(Enum.map(files, & &1.covered)),
      total_missed: Enum.sum(Enum.map(files, & &1.missed)),
      total_cold_lines: Enum.sum(Enum.map(files, & &1.cold_lines)),
      project_max_hits: files |> Enum.map(& &1.max_hits) |> Enum.max(fn -> 0 end),
      percentage: 80.0
    }
  end

  defp render(summary, opts \\ []) do
    dir = System.tmp_dir!() |> Path.join("six_html_#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)
    capture_io(fn -> HTML.format(summary, Keyword.put(opts, :output_dir, dir)) end)
    content = File.read!(Path.join(dir, "coverage.html"))
    File.rm_rf!(dir)
    content
  end

  @demo """
  defmodule Demo do
    # comment line
    @attr "string"
    def build(x) do
      n = x + 123
      {:ok, n}
    end

    def merge(a, b) do
      a + b
    end
  end
  """

  @adj "def a, do: 1\ndef b, do: 2"

  @fb """
  defmodule Fb do
    def calc(x) do
      y = x
      y
    end
  end
  """

  @dyn """
  defmodule Dyn do
    def unquote(:go)(), do: :ok
  end
  """

  defp big_summary do
    mksummary([
      mkfile("lib/demo.ex", @demo, [nil, nil, nil, 1843, 412, 1, 89, nil, 9, 0, 9, nil, nil],
        fc: %{{Demo, :build, 1} => 1843, {Demo, :merge, 2} => 9},
        max: 24_108,
        pct: 80.0
      ),
      mkfile("lib/adj.ex", @adj, [5, 5], max: 1843),
      mkfile("lib/fb.ex", @fb, [nil, 2_000_000, 0, nil, 5, nil, nil], max: 2_000_000),
      mkfile("lib/dyn.ex", @dyn, [nil, 5, nil, nil], max: 5),
      mkfile("lib/tiny.ex", "defmodule Tiny do\n  def t, do: 1\nend", [nil, 122, nil, nil],
        max: 122
      ),
      mkfile("lib/walker.ex", "defmodule Walker do\n  def w, do: :x\nend", [nil, 0, nil, nil],
        pct: 0.0
      )
    ])
  end

  test "writes a self-contained, offline HTML file" do
    content = render(big_summary())

    assert content =~ "<!DOCTYPE html>"
    assert content =~ ~s(class="app-bar")
    assert content =~ "six"
    assert content =~ "coverage"
    refute content =~ "<link"
    refute content =~ "fonts.googleapis"
    refute content =~ ~s(src="http)
  end

  test "renders every per-line heat state" do
    content = render(big_summary())

    for cls <- ~w(h-nil h-0 h-1 h-2 h-3 h-4 h-5) do
      assert content =~ ~s(class="ln #{cls}"), "expected line class #{cls}"
    end
  end

  test "function tooltips show name/arity and call counts" do
    content = render(big_summary())

    assert content =~ ~s(class="fn-range")
    assert content =~ ~s(class="fn-tip")
    # count from function_calls
    assert content =~ "demo.build/1"
    assert content =~ "&times;1,843 calls"
    # count derived from line coverage when function_calls is empty
    assert content =~ "fb.calc/1"
    assert content =~ "&times;2,000,000 calls"
    # arity-less (metaprogrammed) head renders name-only
    assert content =~ "dyn.def"
  end

  test "function tooltips use module-qualified call counts for same function names" do
    source = """
    defmodule One do
      def shared, do: :one
    end

    defmodule Two do
      def shared, do: :two
    end
    """

    summary =
      mksummary([
        mkfile("lib/multi.ex", source, [nil, 2, nil, nil, nil, 5, nil, nil],
          fc: %{{One, :shared, 0} => 2, {Two, :shared, 0} => 5}
        )
      ])

    content = render(summary)

    assert content =~ "multi.shared/0</b> <i>&times;2 calls"
    assert content =~ "multi.shared/0</b> <i>&times;5 calls"
    refute content =~ "&times;7 calls"
  end

  test "function tooltips still support legacy unqualified call maps" do
    source = """
    defmodule Legacy do
      def legacy, do: :ok
    end
    """

    summary =
      mksummary([
        mkfile("lib/legacy.ex", source, [nil, 3, nil, nil], fc: %{{:legacy, 0} => 3})
      ])

    content = render(summary)

    assert content =~ "legacy.legacy/0</b> <i>&times;3 calls"
  end

  test "render shows threshold and marks below-threshold totals" do
    content = render(big_summary(), threshold: 90)

    assert content =~ ~s(class="metric threshold below")
    assert content =~ "<b>90.0%</b><i>threshold</i>"
  end

  test "embedded index JSON escapes script-breaking path characters" do
    source = "defmodule Safe do\n  def ok, do: :ok\nend"

    path =
      "lib/bad</script><script>alert(\"x\")</script>&name\\line\nreturn\rtab\tback\bform\f.ex"

    content = render(mksummary([mkfile(path, source, [nil, 1, nil])]))

    assert content =~ "bad\\u003c/script\\u003e\\u003cscript\\u003ealert"
    assert content =~ "\\u0026name\\\\line\\nreturn\\rtab\\tback\\bform\\f.ex"
    refute content =~ path
  end

  test "syntax highlighter tags keywords, strings, atoms, comments, fn names" do
    content = render(big_summary())

    for cls <- ~w(k s a c fn) do
      assert content =~ ~s(<span class="#{cls}">), "expected token class #{cls}"
    end
  end

  test "coverage ramp colors the bar and pct text" do
    content = render(big_summary())
    # 100% file → deep green; 0% file → deepest red
    assert content =~ "#15803d"
    assert content =~ "#991b1b"
  end

  test "max-hit column abbreviates and shows a ghost dash at zero" do
    content = render(big_summary())

    assert content =~ ">24k<"
    assert content =~ ">1.8k<"
    assert content =~ ">122<"
    assert content =~ ~s(<span class="ghost">&mdash;</span>)
  end

  test "tiny coverage clamps the bar width" do
    content = render(big_summary())
    assert content =~ "width:1.2%"
  end

  test "missed cells flag files with gaps" do
    content = render(big_summary())
    assert content =~ ~s(class="num miss-cell has")
    assert content =~ ~s(class="num miss-cell")
  end

  test "source pane shows scale and footer legend with heatmap on" do
    content = render(big_summary())
    assert content =~ ~s(class="scale")
    assert content =~ "hover any function"
  end

  test "heatmap: false renders binary classes and drops heat chrome" do
    summary = mksummary([mkfile("lib/x.ex", "defmodule X do\n  def a, do: 1\nend", [nil, 5, 0])])
    content = render(summary, heatmap: false)

    assert content =~ "h-cov"
    assert content =~ "h-0"
    assert content =~ "h-nil"
    refute content =~ ~s(class="fn-tip")
    refute content =~ ~s(class="scale")
  end

  test "ignored section lists comment directives and @six attributes, dimmed" do
    source = """
    defmodule Ign do
      # six:ignore:next
      def a, do: 1

      # six:ignore:start
      def b, do: 2
      # six:ignore:stop

      @six :ignore
      def c, do: 3
    end
    """

    content = render(mksummary([mkfile("lib/ign.ex", source, List.duplicate(nil, 11))]))

    assert content =~ "Explicitly ignored"
    assert content =~ ~s(class="ignored")
    assert content =~ "six:ignore:next"
    assert content =~ "six:ignore:start/stop"
    assert content =~ "@six :ignore"
  end

  test "no ignored section when there are no exclusions" do
    content =
      render(
        mksummary([mkfile("lib/clean.ex", "defmodule C do\n  def a, do: 1\nend", [nil, 1, nil])])
      )

    refute content =~ "Explicitly ignored"
  end

  test "parsing source with deprecated syntax emits no warnings" do
    # The literal charlist below is inside an Elixir string, so it only gets
    # parsed (and would warn) when the formatter analyzes it.
    summary =
      mksummary([
        mkfile("lib/legacy.ex", "defmodule L do\n  def g, do: 'hi'\nend", [nil, 1, nil])
      ])

    stderr = capture_io(:stderr, fn -> render(summary) end)
    assert stderr == ""
  end

  test "output_path returns default and respects output_dir" do
    assert HTML.output_path([]) == ".six/coverage.html"
    assert HTML.output_path(output_dir: "custom") == "custom/coverage.html"
  end

  test "format with default opts writes to .six/" do
    capture_io(fn -> HTML.format(big_summary()) end)
    assert File.exists?(".six/coverage.html")
  end
end
