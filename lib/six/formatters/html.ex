defmodule Six.Formatters.HTML do
  @moduledoc false
  @behaviour Six.Formatter

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

  defp render(summary, opts) do
    threshold = Keyword.get(opts, :threshold, 90)
    render_inline(summary, threshold)
  end

  defp render_inline(summary, threshold) do
    files_html =
      summary.files
      |> Enum.sort_by(& &1.percentage)
      |> Enum.map(&file_row_html(&1, threshold))
      |> Enum.join("\n")

    file_details =
      summary.files
      |> Enum.sort_by(& &1.percentage)
      |> Enum.map(&file_detail_html/1)
      |> Enum.join("\n")

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Six Coverage Report</title>
    <style>
    :root {
      --bg: #ffffff; --fg: #1a1a1a; --border: #e0e0e0;
      --green: #22863a; --red: #cb2431; --yellow: #b08800;
      --code-bg: #f6f8fa; --hover: #f0f0f0;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0d1117; --fg: #c9d1d9; --border: #30363d;
        --green: #3fb950; --red: #f85149; --yellow: #d29922;
        --code-bg: #161b22; --hover: #161b22;
      }
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; background: var(--bg); color: var(--fg); padding: 2rem; line-height: 1.5; }
    h1 { margin-bottom: 0.5rem; }
    .summary { font-size: 1.2rem; margin-bottom: 1.5rem; }
    .pct-good { color: var(--green); }
    .pct-bad { color: var(--red); }
    table { width: 100%; border-collapse: collapse; margin-bottom: 2rem; }
    th, td { text-align: left; padding: 0.5rem 1rem; border-bottom: 1px solid var(--border); }
    th { font-weight: 600; }
    tr:hover { background: var(--hover); }
    .bar { width: 200px; height: 8px; background: var(--border); border-radius: 4px; overflow: hidden; display: inline-block; vertical-align: middle; }
    .bar-fill { height: 100%; border-radius: 4px; }
    .file-detail { display: none; margin: 1rem 0 2rem; }
    .file-detail.open { display: block; }
    .file-link { cursor: pointer; color: inherit; text-decoration: underline; }
    pre { background: var(--code-bg); padding: 1rem; border-radius: 6px; overflow-x: auto; font-size: 0.85rem; line-height: 1.6; }
    .hit { background: rgba(34,134,58,0.15); }
    .miss { background: rgba(203,36,49,0.15); }
    .line-num { color: #6e7681; user-select: none; display: inline-block; width: 4em; text-align: right; margin-right: 1em; }
    </style>
    </head>
    <body>
    <h1>Six Coverage Report</h1>
    <div class="summary">
      Total: <span class="#{if summary.percentage >= threshold, do: "pct-good", else: "pct-bad"}">#{format_pct(summary.percentage)}</span>
      &mdash; #{summary.total_covered}/#{summary.total_relevant} relevant lines covered
    </div>
    <table>
    <thead><tr><th>File</th><th>Coverage</th><th>Lines</th><th>Relevant</th><th>Missed</th></tr></thead>
    <tbody>
    #{files_html}
    </tbody>
    </table>
    #{file_details}
    <script>
    document.querySelectorAll('.file-link').forEach(el => {
      el.addEventListener('click', () => {
        const id = el.dataset.file;
        document.getElementById(id).classList.toggle('open');
      });
    });
    </script>
    </body>
    </html>
    """
  end

  defp file_row_html(file, threshold) do
    color = if file.percentage >= threshold, do: "pct-good", else: "pct-bad"
    bar_color = if file.percentage >= threshold, do: "var(--green)", else: "var(--red)"
    file_id = file.path |> String.replace(~r/[^a-zA-Z0-9]/, "-")

    """
    <tr>
      <td><span class="file-link" data-file="#{file_id}">#{escape_html(file.path)}</span></td>
      <td>
        <span class="#{color}">#{format_pct(file.percentage)}</span>
        <div class="bar"><div class="bar-fill" style="width:#{file.percentage}%;background:#{bar_color}"></div></div>
      </td>
      <td>#{file.lines}</td>
      <td>#{file.relevant}</td>
      <td>#{file.missed}</td>
    </tr>
    """
  end

  defp file_detail_html(file) do
    file_id = file.path |> String.replace(~r/[^a-zA-Z0-9]/, "-")
    source_lines = String.split(file.source, "\n")

    lines_html =
      source_lines
      |> Enum.zip(file.coverage)
      |> Enum.with_index(1)
      |> Enum.map(fn {{line, cov}, num} ->
        class =
          case cov do
            nil -> ""
            0 -> " class=\"miss\""
            _ -> " class=\"hit\""
          end

        "<div#{class}><span class=\"line-num\">#{num}</span>#{escape_html(line)}</div>"
      end)
      |> Enum.join("\n")

    """
    <div class="file-detail" id="#{file_id}">
      <h3>#{escape_html(file.path)}</h3>
      <pre>#{lines_html}</pre>
    </div>
    """
  end

  defp format_pct(pct), do: :erlang.float_to_binary(pct / 1, decimals: 1) <> "%"

  defp escape_html(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
