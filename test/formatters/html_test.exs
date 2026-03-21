defmodule Six.Formatters.HTMLTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Six.Formatters.HTML

  defp sample_summary do
    %{
      files: [
        %{
          path: "lib/a.ex",
          source: "def foo, do: :ok\ndef bar, do: :fail\n# comment",
          coverage: [1, 0, nil],
          lines: 3,
          relevant: 2,
          covered: 1,
          missed: 1,
          percentage: 50.0
        }
      ],
      total_lines: 3,
      total_relevant: 2,
      total_covered: 1,
      total_missed: 1,
      percentage: 50.0
    }
  end

  test "format writes HTML file to disk" do
    dir = System.tmp_dir!() |> Path.join("six_html_test_#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)

    capture_io(fn ->
      HTML.format(sample_summary(), output_dir: dir)
    end)

    path = Path.join(dir, "coverage.html")
    assert File.exists?(path)

    content = File.read!(path)
    assert content =~ "<!DOCTYPE html>"
    assert content =~ "Six Coverage Report"
    assert content =~ "lib/a.ex"
    assert content =~ "50.0%"

    File.rm_rf!(dir)
  end

  test "HTML includes hit, miss, and neutral line classes" do
    dir = System.tmp_dir!() |> Path.join("six_html_test_#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)

    capture_io(fn ->
      HTML.format(sample_summary(), output_dir: dir)
    end)

    content = File.read!(Path.join(dir, "coverage.html"))
    assert content =~ "class=\"hit\""
    assert content =~ "class=\"miss\""
    # Nil coverage lines should have no class
    assert content =~ "<div><span"

    File.rm_rf!(dir)
  end

  test "output_path returns default path" do
    assert HTML.output_path([]) == ".six/coverage.html"
  end

  test "output_path respects output_dir option" do
    assert HTML.output_path(output_dir: "custom") == "custom/coverage.html"
  end

  test "format with default opts writes to .six/" do
    capture_io(fn ->
      HTML.format(sample_summary())
    end)

    assert File.exists?(".six/coverage.html")
  end
end
