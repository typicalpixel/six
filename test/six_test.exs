defmodule SixTest do
  use ExUnit.Case

  test "module is available" do
    assert Code.ensure_loaded?(Six)
  end

  test "use Six allows @six :ignore without compiler warnings" do
    # Compile the fixture that uses `use Six` + `@six :ignore`.
    # If the macro didn't register the attribute, compilation would warn.
    [{module, _}] = Code.compile_file("test/fixtures/six_ignore_module.ex")
    assert module == Six.Fixtures.SixIgnoreModule
    assert module.normal_function() == :covered
    assert module.another_normal() == :covered
  end

  describe "report_opts/1" do
    test "returns the project options when mix six set no flags" do
      assert Six.report_opts(summary: [threshold: 90]) == [summary: [threshold: 90]]
    end

    test "appends mix six flags so they override the project options" do
      Application.put_env(:six, :cli_opts, minimum_coverage: 85.0, skip: "gen/")
      on_exit(fn -> Application.delete_env(:six, :cli_opts) end)

      opts = Six.report_opts(minimum_coverage: 100, skip: "lib/")

      config = Six.Config.read() |> Six.Config.merge_with_opts(opts)
      assert config.minimum_coverage == 85.0
      assert config.skip_files == ["lib/", "gen/"]
    end
  end
end
