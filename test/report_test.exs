defmodule Six.ReportTest do
  use ExUnit.Case

  defmodule StubFormatter do
    @behaviour Six.Formatter

    @impl true
    def format(summary, opts) do
      send(self(), {:formatted, summary, opts})
      :ok
    end
  end

  @config_keys [
    :ignore_patterns,
    :default_patterns,
    :minimum_coverage,
    :output_dir,
    :skip_files,
    :formatters,
    :detail,
    :filter,
    :threshold
  ]

  setup do
    previous =
      Enum.map(@config_keys, fn key ->
        {key, Application.get_env(:six, key, :__missing__)}
      end)

    on_exit(fn ->
      Enum.each(@config_keys, fn key ->
        Application.delete_env(:six, key)
      end)

      Enum.each(previous, fn
        {_key, :__missing__} -> :ok
        {key, value} -> Application.put_env(:six, key, value)
      end)
    end)
  end

  test "run returns summary and invokes configured formatter" do
    Application.put_env(:six, :formatters, [StubFormatter])

    summary = Six.Report.run(threshold: 77, output_dir: ".tmp-six")

    assert_receive {:formatted, ^summary, opts}
    assert opts[:threshold] == 77
    assert opts[:output_dir] == ".tmp-six"
    assert is_map(summary)
    assert Map.has_key?(summary, :files)
  end

  test "run uses default opts when none are provided" do
    Application.put_env(:six, :formatters, [StubFormatter])

    summary = Six.Report.run()

    assert_receive {:formatted, ^summary, opts}
    assert opts[:threshold] == 90
    assert opts[:output_dir] == ".six"
  end

  test "run raises when below minimum coverage" do
    Application.put_env(:six, :formatters, [StubFormatter])

    assert_raise Mix.Error, ~r/below the minimum threshold/, fn ->
      Six.Report.run(minimum_coverage: 101.0)
    end
  end
end
