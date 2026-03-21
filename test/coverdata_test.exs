defmodule Six.CoverdataTest do
  use ExUnit.Case

  @moduletag :coverdata

  @tmp_dir System.tmp_dir!()

  defp unique_dir do
    Path.join(@tmp_dir, "six_coverdata_test_#{System.unique_integer([:positive])}")
  end

  describe "import_coverdata" do
    test "imports a valid file" do
      dir = unique_dir()
      File.mkdir_p!(dir)
      coverdata_path = Path.join(dir, "test.coverdata")

      :cover.start()
      :cover.export(String.to_charlist(coverdata_path))
      assert :ok = Six.Cover.import_coverdata(coverdata_path)
      :cover.stop()

      File.rm_rf!(dir)
    end

    test "returns error for nonexistent file" do
      :cover.start()

      assert {:error, _} =
               Six.Cover.import_coverdata(
                 "/tmp/nonexistent_#{System.unique_integer([:positive])}.coverdata"
               )

      :cover.stop()
    end

    test "returns error for corrupt file" do
      dir = unique_dir()
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "bad.coverdata"), "not valid coverdata")

      :cover.start()
      assert {:error, _} = Six.Cover.import_coverdata(Path.join(dir, "bad.coverdata"))
      :cover.stop()

      File.rm_rf!(dir)
    end
  end

  describe "import_all_coverdata" do
    test "imports all files from a directory" do
      dir = unique_dir()
      File.mkdir_p!(dir)

      :cover.start()
      :cover.export(String.to_charlist(Path.join(dir, "part1.coverdata")))
      :cover.export(String.to_charlist(Path.join(dir, "part2.coverdata")))
      {imported, errors} = Six.Cover.import_all_coverdata(dir)
      assert imported == 2
      assert errors == []
      :cover.stop()

      File.rm_rf!(dir)
    end

    test "returns zero for empty directory" do
      dir = unique_dir()
      File.mkdir_p!(dir)

      :cover.start()
      {imported, errors} = Six.Cover.import_all_coverdata(dir)
      assert imported == 0
      assert errors == []
      :cover.stop()

      File.rm_rf!(dir)
    end

    test "handles corrupt files gracefully" do
      dir = unique_dir()
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "bad.coverdata"), "not valid coverdata")

      :cover.start()
      :cover.export(String.to_charlist(Path.join(dir, "good.coverdata")))

      {imported, errors} = Six.Cover.import_all_coverdata(dir)
      assert imported == 1
      assert length(errors) == 1
      [{path, _reason}] = errors
      assert path =~ "bad.coverdata"

      :cover.stop()
      File.rm_rf!(dir)
    end
  end

  describe "partition merge" do
    test "importing two partitions merges their coverage data" do
      dir = unique_dir()
      File.mkdir_p!(dir)
      compile_path = Mix.Project.compile_path()

      # Partition 1: compile modules, call some code, export
      :cover.start()
      Six.Cover.compile_modules(compile_path)
      Six.Config.read()
      :cover.export(String.to_charlist(Path.join(dir, "p1.coverdata")))
      :cover.stop()

      # Partition 2: compile modules, call different code, export
      :cover.start()
      Six.Cover.compile_modules(compile_path)
      Six.Filter.compile_patterns(%{default_patterns: true, ignore_patterns: []})
      :cover.export(String.to_charlist(Path.join(dir, "p2.coverdata")))
      :cover.stop()

      # Merge: import both and verify combined coverage
      :cover.start()
      Six.Cover.compile_modules(compile_path)
      {imported, []} = Six.Cover.import_all_coverdata(dir)
      assert imported == 2

      results = Six.Cover.analyze_all()
      assert map_size(results) > 0

      file_stats = Six.Stats.build(results)
      paths = Enum.map(file_stats, & &1.path)
      assert "lib/six/config.ex" in paths
      assert "lib/six/filter.ex" in paths

      config_stats = Enum.find(file_stats, &(&1.path == "lib/six/config.ex"))
      filter_stats = Enum.find(file_stats, &(&1.path == "lib/six/filter.ex"))
      assert config_stats.covered > 0
      assert filter_stats.covered > 0

      :cover.stop()
      File.rm_rf!(dir)
    end
  end
end
