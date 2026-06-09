defmodule Six.Ignore.LogsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Six.Ignore.Logs

  defp file_stats(source, coverage) do
    %{path: "demo.ex", source: source, coverage: coverage, lines: length(coverage)}
    |> Six.Stats.recalculate()
  end

  describe "the forge#75 scenario: info uncovered, error covered" do
    setup do
      source = """
      defmodule Demo do
        def go(x) do
          Logger.info("inserted",
            a: x.a,
            b: x.b
          )

          Logger.error("failed",
            c: x.a
          )

          :ok
        end
      end\
      """

      coverage = [nil, 1, 1, 0, 0, nil, nil, 1, 1, nil, nil, 1, nil, nil]

      {:ok, source: source, coverage: coverage}
    end

    test "before the feature, the file is below 100%", %{source: source, coverage: coverage} do
      stats = file_stats(source, coverage)
      assert stats.relevant == 7
      assert stats.covered == 5
      assert stats.percentage == 71.4
    end

    test "ignoring :info excludes the whole info call and reaches 100%", ctx do
      [result] = Logs.run([file_stats(ctx.source, ctx.coverage)], %{ignore_log_levels: [:info]})

      assert Enum.at(result.coverage, 2) == nil
      assert Enum.at(result.coverage, 3) == nil
      assert Enum.at(result.coverage, 4) == nil

      assert Enum.at(result.coverage, 7) == 1
      assert Enum.at(result.coverage, 8) == 1

      assert result.relevant == 4
      assert result.covered == 4
      assert result.percentage == 100.0
    end

    test "ignoring an unrelated level leaves the info call counted", ctx do
      [result] = Logs.run([file_stats(ctx.source, ctx.coverage)], %{ignore_log_levels: [:debug]})

      assert Enum.at(result.coverage, 3) == 0
      assert Enum.at(result.coverage, 4) == 0
      assert result.percentage == 71.4
    end
  end

  test "nullifies a single-line log call" do
    source = """
    defmodule Demo do
      def go do
        Logger.debug("noise")
        :ok
      end
    end\
    """

    coverage = [nil, 1, 0, 1, nil, nil]
    [result] = Logs.run([file_stats(source, coverage)], %{ignore_log_levels: [:debug]})

    assert Enum.at(result.coverage, 2) == nil
    assert Enum.at(result.coverage, 3) == 1
    assert result.percentage == 100.0
  end

  test "handles Logger.log/2 where the level is the first argument" do
    source = """
    defmodule Demo do
      def go(x) do
        Logger.log(:info, "msg",
          a: x.a
        )

        :ok
      end
    end\
    """

    coverage = [nil, 1, 1, 0, nil, nil, 1, nil, nil]
    [result] = Logs.run([file_stats(source, coverage)], %{ignore_log_levels: [:info]})

    assert Enum.at(result.coverage, 2) == nil
    assert Enum.at(result.coverage, 3) == nil
    assert result.percentage == 100.0
  end

  test "treats the deprecated :warn alias as :warning" do
    source = """
    defmodule Demo do
      def go do
        Logger.warn("old style")
        :ok
      end
    end\
    """

    coverage = [nil, 1, 0, 1, nil, nil]
    [result] = Logs.run([file_stats(source, coverage)], %{ignore_log_levels: [:warning]})

    assert Enum.at(result.coverage, 2) == nil
    assert result.percentage == 100.0
  end

  test "nullifies a multi-line call written without parentheses" do
    source = """
    defmodule Demo do
      def go(x) do
        Logger.info "no parens",
          a: x.a

        :ok
      end
    end\
    """

    coverage = [nil, 1, 1, 0, nil, 1, nil, nil]
    [result] = Logs.run([file_stats(source, coverage)], %{ignore_log_levels: [:info]})

    assert Enum.at(result.coverage, 2) == nil
    assert Enum.at(result.coverage, 3) == nil
    assert Enum.at(result.coverage, 5) == 1
  end

  test "is a no-op when no levels are configured" do
    source = """
    defmodule Demo do
      def go do
        Logger.info("kept")
        :ok
      end
    end\
    """

    coverage = [nil, 1, 0, 1, nil, nil]
    stats = file_stats(source, coverage)

    assert [^stats] = Logs.run([stats], %{ignore_log_levels: []})
  end

  test "leaves files with no matching log calls unchanged" do
    source = """
    defmodule Demo do
      def go do
        Logger.error("kept")
        :ok
      end
    end\
    """

    coverage = [nil, 1, 1, 1, nil, nil]
    stats = file_stats(source, coverage)

    assert [^stats] = Logs.run([stats], %{ignore_log_levels: [:info]})
  end

  test "warns about unknown levels but still applies the valid ones" do
    source = """
    defmodule Demo do
      def go do
        Logger.info("noise")
        :ok
      end
    end\
    """

    coverage = [nil, 1, 0, 1, nil, nil]

    output =
      capture_io(:stderr, fn ->
        [result] =
          Logs.run([file_stats(source, coverage)], %{ignore_log_levels: [:info, "debug"]})

        send(self(), {:result, result})
      end)

    assert output =~ "unknown log level"
    assert_received {:result, result}
    assert Enum.at(result.coverage, 2) == nil
  end

  test "is a no-op (with a warning) when every configured level is invalid" do
    source = """
    defmodule Demo do
      def go do
        Logger.info("kept")
        :ok
      end
    end\
    """

    coverage = [nil, 1, 0, 1, nil, nil]
    stats = file_stats(source, coverage)

    output =
      capture_io(:stderr, fn ->
        assert [^stats] = Logs.run([stats], %{ignore_log_levels: [:nope]})
      end)

    assert output =~ "unknown log level"
  end

  test "does not match calls on other modules named the same as a level" do
    source = """
    defmodule Demo do
      def go(x) do
        MyLogger.info("not Logger")
        x.info()
        :ok
      end
    end\
    """

    coverage = [nil, 1, 1, 1, 1, nil, nil]
    [result] = Logs.run([file_stats(source, coverage)], %{ignore_log_levels: [:info]})

    assert Enum.at(result.coverage, 2) == 1
    assert Enum.at(result.coverage, 3) == 1
  end

  test "leaves unparseable source untouched" do
    source = "defmodule Bad do\n  def go do\n    Logger.info(\n"
    coverage = [1, 1, 1, nil]
    stats = file_stats(source, coverage)

    assert [^stats] = Logs.run([stats], %{ignore_log_levels: [:info]})
  end

  test "run/2 ignores a config without the ignore_log_levels key" do
    source = "defmodule Demo do\n  def go, do: :ok\nend"
    coverage = [nil, 1, nil]
    stats = file_stats(source, coverage)

    assert [^stats] = Logs.run([stats], %{})
  end
end
