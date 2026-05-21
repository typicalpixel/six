defmodule Six.Formatters.HTML do
  @moduledoc false
  @behaviour Six.Formatter

  alias Six.Heatmap
  alias Six.Ignore

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @impl true
  def format(summary, opts \\ []) do
    output_dir = Keyword.get(opts, :output_dir, ".six")
    path = Path.join(output_dir, "coverage.html")

    html = render(summary, opts)

    File.mkdir_p!(output_dir)
    File.write!(path, html)
    IO.puts("HTML report written to #{path}")
    :ok
  end

  @impl true
  def output_path(opts) do
    Path.join(Keyword.get(opts, :output_dir, ".six"), "coverage.html")
  end

  @doc false
  def render(summary, opts) do
    threshold = Keyword.get(opts, :threshold, 90)
    heatmap? = Keyword.get(opts, :heatmap, true)
    files = Enum.sort_by(summary.files, & &1.percentage)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>six · coverage</title>
    <style>
    #{styles()}
    </style>
    </head>
    <body>
    #{app_bar(summary, threshold)}
    <main>
    #{toolbar(files)}
    <section class="index">
    <table class="modules" id="moduleTable">
      <thead>
        <tr>
          <th data-sort="path">file <span class="arrow">↕</span></th>
          <th data-sort="pct" class="num sorted">cov <span class="arrow">↑</span></th>
          <th class="bar-col">&nbsp;</th>
          <th data-sort="lines" class="num lines-col">lines <span class="arrow">↕</span></th>
          <th data-sort="relevant" class="num rel-col">relevant <span class="arrow">↕</span></th>
          <th data-sort="missed" class="num">missed <span class="arrow">↕</span></th>
          <th data-sort="max" class="num">max&times; <span class="arrow">↕</span></th>
        </tr>
      </thead>
      <tbody id="moduleBody">
    #{Enum.map_join(files, "\n", &module_rows(&1, heatmap?))}
      </tbody>
    </table>
    </section>
    #{ignored_section(files)}
    <div class="foot">six &middot; generated #{stamp()} &middot; single-file report &middot; works offline</div>
    </main>
    <script type="application/json" id="six-index">#{index_json(files)}</script>
    <script type="application/json" id="six-total">#{total_json(summary)}</script>
    <script>
    #{script()}
    </script>
    </body>
    </html>
    """
  end

  # ----------------------------------------------------------------------
  # App bar + toolbar
  # ----------------------------------------------------------------------

  defp app_bar(summary, threshold) do
    pct = summary.percentage
    passing? = pct >= threshold
    color = if passing?, do: cov_color(pct), else: "var(--cov-15)"
    status = if passing?, do: "passing", else: "below"

    """
    <header class="app-bar">
      <div class="brand">
        <span class="dot"></span>
        six
        <span class="sep">&middot;</span>
        <span class="sub">coverage</span>
      </div>
      <div class="run-meta">
        <span><b>generated</b> #{stamp()}</span>
        <span class="pipe">&middot;</span>
        <span><b>#{comma(summary.total_lines)}</b> lines</span>
        <span class="pipe">&middot;</span>
        <span><b>#{comma(summary.total_relevant)}</b> relevant</span>
        <span class="pipe">&middot;</span>
        <span>peak <b>&times;#{comma(Map.get(summary, :project_max_hits, 0))}</b></span>
      </div>
      <div class="totals">
        <div class="metric pct"><b style="color:#{color}">#{format_pct(pct)}</b><i>coverage</i></div>
        <div class="metric threshold #{status}"><b>#{format_pct(threshold)}</b><i>threshold</i></div>
        <div class="metric"><b>#{comma(summary.total_covered)}</b><i>covered</i></div>
        <div class="metric miss"><b>#{comma(summary.total_missed)}</b><i>missed</i></div>
      </div>
    </header>
    """
  end

  defp toolbar(files) do
    """
    <div class="toolbar">
      <h2>Modules</h2>
      <span class="count">#{length(files)} files &middot; sorted by coverage ascending</span>
      <div class="spacer"></div>
      <div class="copygroup">
        <button class="copybtn" data-copy="md">copy as markdown</button>
        <button class="copybtn" data-copy="ascii">copy as plaintext</button>
      </div>
    </div>
    """
  end

  # ----------------------------------------------------------------------
  # Module index rows
  # ----------------------------------------------------------------------

  defp module_rows(file, heatmap?) do
    id = file_id(file.path)
    color = cov_color(file.percentage)
    max = Map.get(file, :max_hits, 0)
    miss_class = if file.missed > 0, do: "miss-cell has", else: "miss-cell"

    max_cell =
      if max > 0,
        do: fmt_hits(max),
        else: ~s(<span class="ghost">&mdash;</span>)

    """
        <tr class="row" data-target="#{id}">
          <td class="path" data-val="#{escape(file.path)}"><span class="chev">&#9656;</span>#{escape(file.path)}</td>
          <td class="num pct" data-val="#{file.percentage}" style="color:#{color}">#{format_pct(file.percentage)}</td>
          <td class="bar-col"><div class="bar"><i style="width:#{bar_width(file.percentage)}%;background:#{color}"></i></div></td>
          <td class="num muted lines-col" data-val="#{file.lines}">#{file.lines}</td>
          <td class="num muted rel-col" data-val="#{file.relevant}">#{file.relevant}</td>
          <td class="num #{miss_class}" data-val="#{file.missed}">#{file.missed}</td>
          <td class="num maxhit" data-val="#{max}">#{max_cell}</td>
        </tr>
        <tr class="source-row" data-target="#{id}"><td colspan="7">#{source_pane(file, heatmap?)}</td></tr>
    """
  end

  defp bar_width(pct) when pct < 1.2, do: 1.2
  defp bar_width(pct), do: pct

  # ----------------------------------------------------------------------
  # Source pane
  # ----------------------------------------------------------------------

  defp source_pane(file, heatmap?) do
    max = Map.get(file, :max_hits, 0)

    miss =
      if file.missed > 0,
        do: ~s(<span class="stat miss"><b>#{file.missed}</b> missed</span>),
        else: ""

    peak =
      if max > 0,
        do: ~s(<span class="stat maxhit">peak <b>&times;#{comma(max)}</b></span>),
        else: ""

    """
    <div class="source-pane">
      <div class="source-header">
        <span class="stat pct"><b>#{format_pct(file.percentage)}</b> coverage</span>
        <span class="stat"><b>#{file.lines}</b> lines</span>
        <span class="stat"><b>#{file.relevant}</b> relevant</span>
        #{miss}
        #{peak}
        #{if heatmap?, do: scale(max), else: ""}
      </div>
      <div class="code">#{code_lines(file, heatmap?)}</div>
      #{if heatmap?, do: source_footer(), else: ""}
    </div>
    """
  end

  defp scale(max) do
    bars =
      0..5
      |> Enum.map_join("", fn b -> ~s|<i style="background:var(--line-#{b}-bg)"></i>| end)

    ~s(<span class="scale"><span>&times;0</span>#{bars}<span>&times;#{fmt_hits(max)}</span></span>)
  end

  defp source_footer do
    legends =
      [
        {"", "&times;0 (never hit)"},
        {"h1", "&times;1"},
        {"h2", "&times;2&ndash;9"},
        {"h3", "&times;10&ndash;99"},
        {"h4", "&times;100&ndash;999"},
        {"h5", "&times;1k+"}
      ]
      |> Enum.map_join("\n", fn {cls, label} ->
        ~s(<span class="legend #{cls}"><i></i> #{label}</span>)
      end)

    """
    <div class="source-footer">
      #{legends}
      <span class="ramp">hover any function for name &middot; arity &middot; total calls</span>
    </div>
    """
  end

  # Render source lines, wrapping each function's lines in a hover region.
  defp code_lines(file, heatmap?) do
    source_lines = String.split(file.source, "\n")
    coverage = file.coverage
    funcs = if heatmap?, do: function_index(file, coverage), else: %{}

    {html, open} =
      source_lines
      |> Enum.zip(coverage)
      |> Enum.with_index(1)
      |> Enum.reduce({[], nil}, fn {{line, cov}, num}, {acc, open} ->
        fun = Map.get(funcs, num)
        {prefix, open} = transition(open, fun)
        {[acc, prefix, line_html(num, line, cov, heatmap?)], open}
      end)

    [html, if(open, do: "</div>", else: "")]
    |> IO.iodata_to_binary()
  end

  # Emits closing/opening fn-range wrappers as the active function changes.
  defp transition(same, same), do: {"", same}
  defp transition(nil, new), do: {open_fn(new), new}
  defp transition(_old, nil), do: {"</div>", nil}
  defp transition(_old, new), do: {["</div>", open_fn(new)], new}

  defp open_fn(%{tip: tip}), do: ~s(<div class="fn-range"><div class="fn-tip">#{tip}</div>)

  defp line_html(num, line, cov, heatmap?) do
    ~s(<div class="ln #{line_heat_class(cov, heatmap?)}"><span class="num">#{num}</span><span class="src">#{src_html(line)}</span></div>)
  end

  defp src_html(""), do: "&nbsp;"
  defp src_html(line), do: highlight(line)

  defp line_heat_class(cov, true), do: "h-" <> heat_suffix(Heatmap.bucket(cov))
  defp line_heat_class(nil, false), do: "h-nil"
  defp line_heat_class(0, false), do: "h-0"
  defp line_heat_class(_, false), do: "h-cov"

  defp heat_suffix(nil), do: "nil"
  defp heat_suffix(:cold), do: "0"
  defp heat_suffix(n), do: Integer.to_string(n)

  # Map of line_number => %{tip: html} for each instrumented function line.
  defp function_index(file, coverage) do
    by_string =
      file
      |> Map.get(:function_calls, %{})
      |> Map.new(fn
        {{module, fun, arity}, count} -> {{module, Atom.to_string(fun), arity}, count}
        {{fun, arity}, count} -> {{nil, Atom.to_string(fun), arity}, count}
      end)

    basename = file.path |> Path.basename() |> String.replace_suffix(".ex", "")

    funcs =
      file.source
      |> Ignore.Functions.functions()
      |> Enum.reject(&entirely_uninstrumented?(&1, coverage))

    Enum.reduce(funcs, %{}, fn fun, acc ->
      tip = fn_tip(fun, basename, by_string, coverage)
      entry = %{key: {fun.start_line, fun.end_line}, tip: tip}
      Enum.reduce(fun.start_line..fun.end_line, acc, &Map.put(&2, &1, entry))
    end)
  end

  defp fn_tip(fun, basename, by_string, coverage) do
    name = bare_name(fun.function)
    label = if fun.arity, do: "#{name}/#{fun.arity}", else: name

    # Instrumented functions always have a count (line fallback below never
    # returns nil once entirely-uninstrumented functions are filtered out).
    calls =
      Map.get(by_string, {fun.module, name, fun.arity}) ||
        Map.get(by_string, {nil, name, fun.arity}) ||
        max_in_range(coverage, fun.start_line, fun.end_line)

    ~s(<b>#{escape(basename)}.#{escape(label)}</b> <i>&times;#{comma(calls)} calls</i>)
  end

  defp entirely_uninstrumented?(%{start_line: s, end_line: e}, coverage) do
    coverage |> Enum.slice((s - 1)..(e - 1)) |> Enum.all?(&is_nil/1)
  end

  defp bare_name(function) do
    function |> String.split(" ", parts: 2) |> List.last()
  end

  defp max_in_range(coverage, s, e) do
    coverage
    |> Enum.slice((s - 1)..(e - 1))
    |> Enum.reduce(nil, fn
      n, acc when is_integer(n) and (acc == nil or n > acc) -> n
      _, acc -> acc
    end)
  end

  # ----------------------------------------------------------------------
  # Ignored section (dimmed, at the bottom — not the focus)
  # ----------------------------------------------------------------------

  defp ignored_section(files) do
    entries =
      Enum.flat_map(files, fn file ->
        comment_entries =
          Enum.map(Ignore.ignored_ranges(file.source), fn {s, e, type} ->
            label = if type == :block, do: "six:ignore:start/stop", else: "six:ignore:next"
            {file.path, s, e, label, nil}
          end)

        func_entries =
          Enum.map(Ignore.Functions.ignored_functions(file.source), fn %{
                                                                         start_line: s,
                                                                         end_line: e,
                                                                         function: func
                                                                       } ->
            {file.path, s, e, "@six :ignore", func}
          end)

        comment_entries ++ func_entries
      end)

    case entries do
      [] ->
        ""

      entries ->
        rows =
          Enum.map_join(entries, "\n", fn {path, s, e, label, func} ->
            func_part = if func, do: ~s( <code>#{escape(func)}</code>), else: ""

            ~s(<li><span class="loc">#{escape(path)}:#{s}&ndash;#{e}</span>#{func_part} <span class="tag">#{label}</span></li>)
          end)

        """
        <section class="ignored">
          <h2>Explicitly ignored <span class="count">#{length(entries)}</span></h2>
          <p class="note">Excluded from coverage on purpose &mdash; not counted above.</p>
          <ul>
        #{rows}
          </ul>
        </section>
        """
    end
  end

  # ----------------------------------------------------------------------
  # JSON payloads (for copy-as-markdown / plaintext) — no JSON dep
  # ----------------------------------------------------------------------

  defp index_json(files) do
    files
    |> Enum.map_join(",", fn f ->
      ~s({"path":#{json_string(f.path)},"pct":#{f.percentage},"lines":#{f.lines},"relevant":#{f.relevant},"missed":#{f.missed},"max":#{Map.get(f, :max_hits, 0)}})
    end)
    |> then(&"[#{&1}]")
  end

  defp total_json(summary) do
    ~s({"pct":#{summary.percentage},"relevant":#{summary.total_relevant},"covered":#{summary.total_covered},"missed":#{summary.total_missed}})
  end

  defp json_string(str) do
    escaped =
      str
      |> String.graphemes()
      |> Enum.map_join(&json_escape/1)

    "\"#{escaped}\""
  end

  defp json_escape("\""), do: "\\\""
  defp json_escape("\\"), do: "\\\\"
  defp json_escape("\b"), do: "\\b"
  defp json_escape("\f"), do: "\\f"
  defp json_escape("\n"), do: "\\n"
  defp json_escape("\r"), do: "\\r"
  defp json_escape("\t"), do: "\\t"
  defp json_escape("<"), do: "\\u003c"
  defp json_escape(">"), do: "\\u003e"
  defp json_escape("&"), do: "\\u0026"
  defp json_escape(g), do: g

  # ----------------------------------------------------------------------
  # Formatting helpers
  # ----------------------------------------------------------------------

  defp file_id(path), do: "file-" <> String.replace(path, ~r/[^a-zA-Z0-9]/, "-")

  defp format_pct(pct), do: :erlang.float_to_binary(pct / 1, decimals: 1) <> "%"

  # File coverage ramp: 100% deep green down through lime/amber/pink to red —
  # a half-covered file IS half-tested, so the whole spectrum is in play.
  @cov_stops [
    {100, "#15803d"},
    {95, "#16a34a"},
    {85, "#22c55e"},
    {75, "#65a30d"},
    {65, "#84cc16"},
    {55, "#ca8a04"},
    {50, "#d97706"},
    {40, "#db2777"},
    {30, "#e11d48"},
    {15, "#dc2626"},
    {0, "#991b1b"}
  ]

  defp cov_color(pct) do
    {_bound, hex} = Enum.find(@cov_stops, fn {bound, _} -> pct >= bound end)
    hex
  end

  defp fmt_hits(n) when n >= 1000 do
    decimals = if n >= 10_000, do: 0, else: 1

    (n / 1000)
    |> :erlang.float_to_binary(decimals: decimals)
    |> String.replace_suffix(".0", "")
    |> Kernel.<>("k")
  end

  defp fmt_hits(n), do: Integer.to_string(n)

  defp comma(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp stamp do
    {{y, mo, d}, {h, mi, _}} = :calendar.universal_time()

    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B UTC", [y, mo, d, h, mi])
    |> IO.iodata_to_binary()
  end

  defp escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  # ----------------------------------------------------------------------
  # Lightweight, escape-safe Elixir syntax highlighter
  # (small, conservative tints: keyword / string / atom / comment / fn-name)
  # ----------------------------------------------------------------------

  @keywords ~w(def defp defmodule defmacro defmacrop defguard defguardp defstruct
               defexception defprotocol defimpl defdelegate do end fn when case cond
               with if unless else for receive try catch rescue after import alias
               require use quote unquote raise throw true false nil and or not in)

  @def_keywords ~w(def defp defmacro defmacrop defguard defguardp)

  @re_string ~r/\A"(?:[^"\\]|\\.)*"/
  @re_atom ~r/\A:[a-zA-Z_][a-zA-Z0-9_]*[?!]?/
  @re_number ~r/\A\d[\d_]*(?:\.\d+)?/
  @re_ident ~r/\A[A-Za-z_][a-zA-Z0-9_]*[?!]?/
  @re_space ~r/\A[ \t]+/

  defp highlight(line), do: line |> tokenize(:start, []) |> IO.iodata_to_binary()

  defp tokenize("", _state, acc), do: Enum.reverse(acc)

  defp tokenize(rest, state, acc) do
    case token(rest) do
      {:comment, t, r} -> tokenize(r, :other, [span("c", t) | acc])
      {:string, t, r} -> tokenize(r, :other, [span("s", t) | acc])
      {:atom, t, r} -> tokenize(r, :other, [span("a", t) | acc])
      {:number, t, r} -> tokenize(r, :other, [escape(t) | acc])
      {:space, t, r} -> tokenize(r, state, [escape(t) | acc])
      {:ident, t, r} -> tokenize(r, ident_state(t), [ident_html(t, state) | acc])
      {:char, t, r} -> tokenize(r, :other, [escape(t) | acc])
    end
  end

  defp token("#" <> _ = rest), do: {:comment, rest, ""}

  defp token(rest) do
    cond do
      m = run(@re_string, rest) -> {:string, m, drop(rest, m)}
      m = run(@re_atom, rest) -> {:atom, m, drop(rest, m)}
      m = run(@re_number, rest) -> {:number, m, drop(rest, m)}
      m = run(@re_ident, rest) -> {:ident, m, drop(rest, m)}
      m = run(@re_space, rest) -> {:space, m, drop(rest, m)}
      true -> next_char(rest)
    end
  end

  defp ident_state(t) when t in @def_keywords, do: :after_def
  defp ident_state(_), do: :other

  defp ident_html(t, state) do
    cond do
      t in @keywords -> span("k", t)
      state == :after_def -> span("fn", t)
      true -> escape(t)
    end
  end

  defp run(re, s) do
    case Regex.run(re, s) do
      [m | _] -> m
      _ -> nil
    end
  end

  defp drop(s, m), do: binary_part(s, byte_size(m), byte_size(s) - byte_size(m))

  defp next_char(rest) do
    {g, r} = String.next_grapheme(rest)
    {:char, g, r}
  end

  defp span(class, text), do: [~s(<span class="), class, ~s(">), escape(text), "</span>"]

  # ----------------------------------------------------------------------
  # Inlined static assets
  # ----------------------------------------------------------------------

  defp styles do
    ~S"""
    :root {
      --bg: #f8fafc; --bg-2: #f1f5f9; --bg-3: #e2e8f0;
      --fg: #0f172a; --fg-2: #1e293b; --fg-3: #475569; --fg-4: #64748b; --fg-5: #94a3b8;
      --border: #e2e8f0; --border-2: #cbd5e1;
      --shadow: 0 1px 0 rgba(15,23,42,0.04), 0 1px 2px rgba(15,23,42,0.04);

      /* Per-line heat: ×0 is the only bad state; ×1+ darkens green with hits. */
      --line-nil: transparent;
      --line-0-bg: #fee2e2; --line-0-num: #b91c1c;
      --line-1-bg: #f0fdf4; --line-2-bg: #dcfce7; --line-3-bg: #bbf7d0;
      --line-4-bg: #86efac; --line-5-bg: #4ade80; --line-cov-bg: #bbf7d0;

      /* File coverage ramp — bar fill + pct text */
      --cov-100: #15803d; --cov-90: #16a34a; --cov-15: #dc2626;

      --syn-kw: #7c3aed; --syn-str: #0369a1; --syn-fn: #0f766e;
      --syn-cmt: #94a3b8; --syn-atom: #b45309;

      --font-ui: -apple-system, BlinkMacSystemFont, "Segoe UI", "Inter", Roboto, "Helvetica Neue", Arial, sans-serif;
      --font-mono: ui-monospace, "SF Mono", "JetBrains Mono", "Menlo", "Consolas", "Liberation Mono", monospace;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0b1220; --bg-2: #111a2e; --bg-3: #1e293b;
        --fg: #e2e8f0; --fg-2: #cbd5e1; --fg-3: #94a3b8; --fg-4: #64748b; --fg-5: #475569;
        --border: #1e293b; --border-2: #334155;
        --shadow: 0 1px 0 rgba(0,0,0,0.4);
        --line-0-bg: #450a0a; --line-0-num: #fca5a5;
        --line-1-bg: #052e16; --line-2-bg: #14532d; --line-3-bg: #166534;
        --line-4-bg: #15803d; --line-5-bg: #16a34a; --line-cov-bg: #166534;
        --syn-kw: #c4b5fd; --syn-str: #7dd3fc; --syn-fn: #5eead4;
        --syn-cmt: #64748b; --syn-atom: #fcd34d;
      }
    }

    * { box-sizing: border-box; }
    html { background: var(--bg); }
    body {
      margin: 0; font-family: var(--font-ui); font-size: 13.5px; line-height: 1.5;
      color: var(--fg); -webkit-font-smoothing: antialiased; text-rendering: optimizeLegibility;
    }

    .app-bar {
      position: sticky; top: 0; z-index: 20; background: var(--bg);
      border-bottom: 1px solid var(--border); padding: 10px 24px;
      display: grid; grid-template-columns: auto 1fr auto; gap: 24px; align-items: center;
    }
    .brand {
      font-family: var(--font-mono); font-weight: 700; font-size: 13px;
      letter-spacing: 0.04em; text-transform: uppercase; color: var(--fg);
      display: inline-flex; align-items: center; gap: 8px;
    }
    .brand .dot {
      width: 9px; height: 9px; border-radius: 2px; background: var(--cov-100);
      box-shadow: 0 0 0 3px color-mix(in oklch, var(--cov-100) 22%, transparent);
    }
    .brand .sep { color: var(--fg-5); font-weight: 400; }
    .brand .sub { color: var(--fg-3); font-weight: 500; letter-spacing: 0; text-transform: none; }
    .run-meta {
      color: var(--fg-4); font-size: 12px; display: flex; gap: 14px; align-items: center;
      font-variant-numeric: tabular-nums;
    }
    .run-meta b { color: var(--fg-2); font-weight: 600; }
    .run-meta .pipe { color: var(--border-2); }
    .totals { display: flex; gap: 4px; align-items: center; }
    .metric {
      padding: 4px 14px; border-left: 1px solid var(--border);
      display: flex; flex-direction: column; align-items: flex-end;
      font-variant-numeric: tabular-nums; min-width: 78px;
    }
    .metric b { font-weight: 600; font-size: 18px; letter-spacing: -0.01em; line-height: 1.1; }
    .metric i {
      font-style: normal; font-size: 10.5px; text-transform: uppercase;
      letter-spacing: 0.06em; color: var(--fg-4); margin-top: 2px;
    }
    .metric.pct b { font-size: 22px; }
    .metric.miss b { color: var(--cov-15); }
    .metric.threshold.below b { color: var(--cov-15); }
    .metric.threshold.passing b { color: var(--cov-100); }

    main { max-width: 1280px; margin: 0 auto; padding: 18px 24px 64px; }
    .toolbar { display: flex; align-items: baseline; gap: 14px; padding: 6px 4px 12px; }
    .toolbar h2 {
      margin: 0; font-size: 11.5px; font-weight: 600; letter-spacing: 0.08em;
      text-transform: uppercase; color: var(--fg-3);
    }
    .toolbar .count { color: var(--fg-4); font-variant-numeric: tabular-nums; font-size: 12px; }
    .toolbar .spacer { flex: 1; }
    .copygroup { display: inline-flex; gap: 4px; }
    .copybtn {
      display: inline-flex; align-items: center; gap: 6px; font-family: var(--font-ui);
      font-size: 12px; font-weight: 500; color: var(--fg-2); background: var(--bg);
      border: 1px solid var(--border-2); padding: 5px 10px; border-radius: 4px;
      cursor: pointer; transition: background 0.12s, border-color 0.12s, color 0.12s;
    }
    .copybtn:hover { background: var(--bg-2); border-color: var(--fg-5); }
    .copybtn:active { background: var(--bg-3); }
    .copybtn.copied {
      background: color-mix(in oklch, var(--cov-100) 15%, var(--bg));
      border-color: var(--cov-100); color: var(--cov-100);
    }

    .index { border: 1px solid var(--border); border-radius: 6px; background: var(--bg); box-shadow: var(--shadow); }
    table.modules { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 12.5px; }
    table.modules thead th:first-child { border-top-left-radius: 5px; }
    table.modules thead th:last-child { border-top-right-radius: 5px; }
    table.modules tbody tr:last-child td:first-child { border-bottom-left-radius: 5px; }
    table.modules tbody tr:last-child td:last-child { border-bottom-right-radius: 5px; }
    table.modules thead th {
      text-align: left; font-size: 10.5px; font-weight: 600; text-transform: uppercase;
      letter-spacing: 0.06em; color: var(--fg-4); padding: 8px 14px; background: var(--bg-2);
      border-bottom: 1px solid var(--border); user-select: none; cursor: pointer;
      white-space: nowrap; position: sticky; top: var(--appbar-h, 56px); z-index: 1;
    }
    table.modules thead th .arrow { opacity: 0.4; margin-left: 4px; font-size: 9px; }
    table.modules thead th.sorted .arrow { opacity: 1; color: var(--fg-2); }
    table.modules thead th.num { text-align: right; }
    table.modules thead th.bar-col { width: 160px; }
    table.modules tbody td {
      padding: 7px 14px; border-bottom: 1px solid var(--border); vertical-align: middle;
      font-variant-numeric: tabular-nums;
    }
    table.modules tbody tr:last-child td { border-bottom: none; }
    table.modules tbody tr.row { cursor: pointer; transition: background 0.08s; }
    table.modules tbody tr.row:hover td { background: var(--bg-2); }
    table.modules tbody tr.row.open td { background: var(--bg-2); }
    table.modules tbody tr.row.open td.path { font-weight: 600; }
    td.num { text-align: right; }
    td.path { font-family: var(--font-mono); font-size: 12.5px; color: var(--fg); white-space: nowrap; }
    td.path .chev { display: inline-block; width: 10px; color: var(--fg-5); transition: transform 0.12s; margin-right: 4px; }
    tr.row.open td.path .chev { transform: rotate(90deg); color: var(--fg-3); }
    td.muted { color: var(--fg-4); }
    td.pct { font-family: var(--font-mono); font-weight: 600; font-size: 12.5px; width: 60px; }
    .bar { position: relative; width: 140px; height: 6px; background: var(--bg-3); border-radius: 3px; overflow: hidden; }
    .bar > i { display: block; height: 100%; border-radius: 3px; }
    td.maxhit { color: var(--fg-3); font-family: var(--font-mono); font-size: 12px; }
    td.maxhit .ghost { color: var(--fg-5); }
    td.miss-cell { color: var(--fg-4); }
    td.miss-cell.has { color: var(--cov-15); font-weight: 600; }

    tr.source-row { display: none; }
    tr.source-row.open { display: table-row; }
    tr.source-row > td { padding: 0; background: var(--bg); border-bottom: 1px solid var(--border); }
    .source-pane { background: var(--bg); border-top: 1px solid var(--border); }
    .source-header {
      display: flex; align-items: center; gap: 14px; padding: 8px 16px; background: var(--bg-2);
      border-bottom: 1px solid var(--border); font-family: var(--font-mono); font-size: 11.5px; color: var(--fg-3);
    }
    .source-header .stat { display: inline-flex; align-items: center; gap: 5px; }
    .source-header .stat b { color: var(--fg); font-weight: 600; }
    .source-header .stat::before { content: ''; width: 6px; height: 6px; border-radius: 50%; background: var(--fg-5); }
    .source-header .stat.pct::before { background: var(--cov-100); }
    .source-header .stat.miss::before { background: var(--cov-15); }
    .source-header .stat.maxhit::before { background: var(--syn-kw); }
    .source-header .scale {
      margin-left: auto; display: inline-flex; align-items: center; border: 1px solid var(--border);
      border-radius: 3px; background: var(--bg); padding: 2px;
    }
    .source-header .scale > span { font-size: 10px; color: var(--fg-3); padding: 2px 6px 2px 8px; }
    .source-header .scale > i { display: block; width: 16px; height: 14px; border-radius: 2px; margin: 0 1px; }

    .code { font-family: var(--font-mono); font-size: 12px; line-height: 1.55; background: var(--bg); max-height: 580px; overflow: auto; }
    .code .ln { display: grid; grid-template-columns: 54px 1fr; align-items: stretch; }
    .code .ln > .num {
      text-align: right; padding: 0 12px 0 16px; color: var(--fg-5); background: var(--bg);
      border-right: 1px solid var(--border); user-select: none; font-variant-numeric: tabular-nums; position: relative;
    }
    .code .ln > .src { padding: 0 14px; white-space: pre; color: var(--fg); position: relative; }
    .code .ln:hover > .src { box-shadow: inset 0 0 0 9999px rgba(15,23,42,0.025); }
    .code .ln.h-nil > .src { background: var(--line-nil); }
    .code .ln.h-0 > .src { background: var(--line-0-bg); }
    .code .ln.h-1 > .src { background: var(--line-1-bg); }
    .code .ln.h-2 > .src { background: var(--line-2-bg); }
    .code .ln.h-3 > .src { background: var(--line-3-bg); }
    .code .ln.h-4 > .src { background: var(--line-4-bg); }
    .code .ln.h-5 > .src { background: var(--line-5-bg); }
    .code .ln.h-cov > .src { background: var(--line-cov-bg); }
    .code .ln.h-0 > .num { color: var(--line-0-num); font-weight: 600; }
    .code .ln.h-nil > .num { color: var(--fg-5); }
    .code .ln.h-0 > .num::after, .code .ln.h-1 > .num::after, .code .ln.h-2 > .num::after,
    .code .ln.h-3 > .num::after, .code .ln.h-4 > .num::after, .code .ln.h-5 > .num::after {
      content: ''; position: absolute; right: -1px; top: 0; bottom: 0; width: 3px;
    }
    .code .ln.h-0 > .num::after { background: var(--cov-15); }
    .code .ln.h-1 > .num::after { background: var(--line-3-bg); }
    .code .ln.h-2 > .num::after { background: var(--line-4-bg); }
    .code .ln.h-3 > .num::after { background: var(--line-5-bg); }
    .code .ln.h-4 > .num::after { background: var(--cov-90); }
    .code .ln.h-5 > .num::after { background: var(--cov-100); }

    .k { color: var(--syn-kw); }
    .s { color: var(--syn-str); }
    .fn { color: var(--syn-fn); }
    .c { color: var(--syn-cmt); font-style: italic; }
    .a { color: var(--syn-atom); }

    .fn-range { position: relative; }
    .fn-tip {
      position: absolute; left: 60px; top: -36px; background: var(--fg); color: var(--bg);
      font-family: var(--font-mono); font-size: 11px; padding: 6px 10px; border-radius: 4px;
      white-space: nowrap; pointer-events: none; opacity: 0; transform: translateY(2px);
      transition: opacity 0.12s, transform 0.12s; box-shadow: 0 4px 12px rgba(15,23,42,0.18); z-index: 5;
    }
    .fn-tip::after {
      content: ''; position: absolute; left: 16px; bottom: -5px;
      border: 5px solid transparent; border-top-color: var(--fg); border-bottom: 0;
    }
    .fn-tip b { color: #fbbf24; font-weight: 600; }
    .fn-tip i { font-style: normal; color: var(--fg-5); margin-left: 6px; font-size: 10.5px; }
    .fn-range:hover > .fn-tip { opacity: 1; transform: translateY(0); }

    .source-footer {
      padding: 8px 16px; background: var(--bg-2); border-top: 1px solid var(--border);
      display: flex; gap: 14px; align-items: center; font-size: 11px; color: var(--fg-4); font-family: var(--font-mono);
    }
    .source-footer .legend { display: inline-flex; gap: 4px; align-items: center; }
    .source-footer .legend > i {
      width: 14px; height: 12px; border-radius: 2px; background: var(--line-0-bg);
      border: 1px solid color-mix(in oklch, currentColor 18%, transparent);
    }
    .source-footer .legend.h1 > i { background: var(--line-1-bg); }
    .source-footer .legend.h2 > i { background: var(--line-2-bg); }
    .source-footer .legend.h3 > i { background: var(--line-3-bg); }
    .source-footer .legend.h4 > i { background: var(--line-4-bg); }
    .source-footer .legend.h5 > i { background: var(--line-5-bg); }
    .source-footer .ramp { margin-left: auto; }

    .ignored { margin-top: 28px; padding-top: 14px; border-top: 1px solid var(--border); opacity: 0.55; transition: opacity 0.12s; }
    .ignored:hover { opacity: 1; }
    .ignored h2 { font-size: 11.5px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; color: var(--fg-3); margin: 0 0 2px; }
    .ignored .count { font-size: 11px; color: var(--fg-5); font-weight: 400; letter-spacing: 0; text-transform: none; }
    .ignored .note { margin: 0 0 8px; font-size: 12px; color: var(--fg-4); }
    .ignored ul { list-style: none; margin: 0; padding: 0; font-size: 12px; }
    .ignored li { padding: 2px 0; }
    .ignored .loc { font-family: var(--font-mono); color: var(--fg-3); }
    .ignored code { font-family: var(--font-mono); color: var(--fg-2); }
    .ignored .tag { color: var(--fg-5); font-size: 11px; }

    .foot { margin-top: 18px; font-size: 11px; color: var(--fg-4); text-align: center; font-family: var(--font-mono); }

    @media (max-width: 900px) {
      table.modules thead th.bar-col, table.modules tbody td.bar-col,
      table.modules thead th.lines-col, table.modules tbody td.lines-col,
      table.modules thead th.rel-col, table.modules tbody td.rel-col { display: none; }
    }
    """
  end

  defp script do
    ~S"""
    (function () {
      var table = document.getElementById('moduleTable');
      if (!table) return;
      var tbody = document.getElementById('moduleBody');
      var ths = Array.prototype.slice.call(table.tHead.rows[0].cells);

      function setAppBarHeight() {
        var bar = document.querySelector('.app-bar');
        if (bar) document.documentElement.style.setProperty('--appbar-h', Math.round(bar.getBoundingClientRect().height) + 'px');
      }
      setAppBarHeight();
      window.addEventListener('resize', setAppBarHeight);

      tbody.addEventListener('click', function (e) {
        var row = e.target.closest('tr.row');
        if (!row) return;
        var src = row.nextElementSibling;
        if (src && src.classList.contains('source-row')) {
          var open = src.classList.toggle('open');
          row.classList.toggle('open', open);
        }
      });

      function sortBy(key, dir) {
        var idx = ths.findIndex(function (th) { return th.dataset.sort === key; });
        if (idx < 0) return;
        var pairs = [];
        Array.prototype.forEach.call(tbody.rows, function (r) {
          if (r.classList.contains('row')) pairs.push([r]);
          else if (pairs.length) pairs[pairs.length - 1].push(r);
        });
        pairs.sort(function (a, b) {
          var va = a[0].cells[idx].dataset.val, vb = b[0].cells[idx].dataset.val;
          var na = parseFloat(va), nb = parseFloat(vb), cmp;
          if (!isNaN(na) && !isNaN(nb)) cmp = na - nb;
          else cmp = String(va).localeCompare(String(vb));
          return dir < 0 ? -cmp : cmp;
        });
        pairs.forEach(function (p) { p.forEach(function (r) { tbody.appendChild(r); }); });
        ths.forEach(function (th) {
          var on = th.dataset.sort === key;
          th.classList.toggle('sorted', on);
          var arr = th.querySelector('.arrow');
          if (arr) arr.textContent = on ? (dir < 0 ? '↓' : '↑') : '↕';
        });
        location.hash = 'sort=' + key + ',' + (dir < 0 ? 'desc' : 'asc');
      }

      var curKey = 'pct', curDir = 1;
      ths.forEach(function (th) {
        if (!th.dataset.sort) return;
        th.addEventListener('click', function () {
          var k = th.dataset.sort;
          if (k === curKey) curDir = -curDir;
          else { curKey = k; curDir = (k === 'pct' || k === 'missed' || k === 'path') ? 1 : -1; }
          sortBy(curKey, curDir);
        });
      });

      var m = location.hash.match(/sort=([^,]+),(asc|desc)/);
      if (m) { curKey = m[1]; curDir = m[2] === 'desc' ? -1 : 1; sortBy(curKey, curDir); }

      var INDEX = JSON.parse(document.getElementById('six-index').textContent);
      var TOTAL = JSON.parse(document.getElementById('six-total').textContent);
      var COLS = [
        { k: 'path', label: 'file', w: 34, align: 'l' },
        { k: 'pct', label: 'cov%', w: 6, align: 'r', f: function (v) { return v.toFixed(1); } },
        { k: 'lines', label: 'lines', w: 6, align: 'r' },
        { k: 'relevant', label: 'relevant', w: 9, align: 'r' },
        { k: 'missed', label: 'missed', w: 7, align: 'r' },
        { k: 'max', label: 'max', w: 9, align: 'r', f: function (v) { return v.toLocaleString(); } }
      ];

      function totalLine() {
        return 'six coverage · ' + TOTAL.pct.toFixed(1) + '% · ' + TOTAL.covered + '/' + TOTAL.relevant + ' relevant · ' + TOTAL.missed + ' missed';
      }
      function fmtMd() {
        var head = '| ' + COLS.map(function (c) { return c.label; }).join(' | ') + ' |';
        var sep = '|' + COLS.map(function (c) { return c.align === 'r' ? '---:' : '---'; }).join('|') + '|';
        var rows = INDEX.map(function (r) {
          return '| ' + COLS.map(function (c) {
            var v = c.f ? c.f(r[c.k]) : r[c.k];
            return c.k === 'path' ? '`' + v + '`' : v;
          }).join(' | ') + ' |';
        });
        return ['**' + totalLine() + '**', '', head, sep].concat(rows).join('\n');
      }
      function pad(s, w, a) { s = String(s); return a === 'r' ? s.padStart(w) : s.padEnd(w); }
      function fmtAscii() {
        var sep = COLS.map(function (c) { return '─'.repeat(c.w); }).join('  ');
        var header = COLS.map(function (c) { return pad(c.label, c.w, c.align); }).join('  ');
        var body = INDEX.map(function (r) {
          return COLS.map(function (c) { return pad(c.f ? c.f(r[c.k]) : r[c.k], c.w, c.align); }).join('  ');
        });
        return [totalLine(), sep, header, sep].concat(body, [sep]).join('\n');
      }
      function copyText(txt) {
        if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(txt);
        return new Promise(function (resolve, reject) {
          var ta = document.createElement('textarea');
          ta.value = txt; ta.style.position = 'fixed'; ta.style.top = '-1000px';
          document.body.appendChild(ta); ta.select();
          var ok = false;
          try { ok = document.execCommand('copy'); } catch (e) {}
          document.body.removeChild(ta);
          ok ? resolve() : reject();
        });
      }
      Array.prototype.forEach.call(document.querySelectorAll('.copybtn'), function (btn) {
        btn.addEventListener('click', function () {
          var txt = btn.dataset.copy === 'md' ? fmtMd() : fmtAscii();
          var prev = btn.textContent;
          copyText(txt).then(function () { btn.textContent = 'copied'; }, function () { btn.textContent = 'copy failed'; })
            .then(function () { setTimeout(function () { btn.textContent = prev; }, 1400); });
        });
      });
    })();
    """
  end
end
