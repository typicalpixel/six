defmodule Six.ConfigTest do
  use ExUnit.Case

  alias Six.Config

  test "read returns defaults when no config is set" do
    keys =
      ~w(ignore_patterns default_patterns minimum_coverage output_dir skip_files formatters detail filter threshold track_ignores)a

    saved = for k <- keys, do: {k, Application.get_env(:six, k)}
    Enum.each(keys, &Application.delete_env(:six, &1))

    on_exit(fn ->
      Enum.each(saved, fn
        {k, nil} -> Application.delete_env(:six, k)
        {k, v} -> Application.put_env(:six, k, v)
      end)
    end)

    config = Config.read()

    assert config.ignore_patterns == []
    assert config.default_patterns == true
    assert config.minimum_coverage == 0
    assert config.output_dir == ".six"
    assert config.skip_files == []
    assert config.formatters == [Six.Formatters.Terminal, Six.Formatters.Agent]
    assert config.threshold == 90
    assert config.track_ignores == false
  end

  test "merge_with_opts enables track_ignores" do
    config = Config.read()
    updated = Config.merge_with_opts(config, track_ignores: true)
    assert updated.track_ignores == true
  end

  test "merge_with_opts overrides fields" do
    config = Config.read()

    updated =
      Config.merge_with_opts(config,
        threshold: 80,
        output_dir: "my_cover",
        detail: true,
        filter: "stats"
      )

    assert updated.threshold == 80
    assert updated.output_dir == "my_cover"
    assert updated.detail == true
    assert updated.filter == "stats"
  end

  test "merge_with_opts handles summary opts" do
    config = Config.read()
    updated = Config.merge_with_opts(config, summary: [threshold: 75])
    assert updated.threshold == 75
  end

  test "merge_with_opts accumulates skip patterns" do
    config = Config.read()
    updated = Config.merge_with_opts(config, skip: "generated/")
    assert updated.skip_files == ["generated/"]
  end

  test "merge_with_opts appends skip_files lists" do
    config = Config.read()
    updated = Config.merge_with_opts(config, skip_files: ["generated/", "_pb.ex"])
    assert updated.skip_files == ["generated/", "_pb.ex"]
  end

  test "merge_with_opts overrides minimum coverage" do
    config = Config.read()
    updated = Config.merge_with_opts(config, minimum_coverage: 85.5)
    assert updated.minimum_coverage == 85.5
  end

  test "merge_with_opts overrides formatters" do
    config = Config.read()
    updated = Config.merge_with_opts(config, formatters: [Six.Formatters.Terminal])
    assert updated.formatters == [Six.Formatters.Terminal]
  end

  test "merge_with_opts ignores unknown summary opts" do
    config = Config.read()
    updated = Config.merge_with_opts(config, summary: [unknown_key: true, threshold: 80])
    assert updated.threshold == 80
  end
end
