defmodule Mix.Tasks.SixTest do
  use ExUnit.Case

  describe "split_args" do
    test "parses threshold option" do
      {opts, test_args} = Mix.Tasks.Six.split_args(["--threshold", "80"])
      assert opts[:threshold] == 80
      assert test_args == []
    end

    test "parses output-dir option" do
      {opts, _} = Mix.Tasks.Six.split_args(["--output-dir", "my_cover"])
      assert opts[:output_dir] == "my_cover"
    end

    test "parses minimum coverage option" do
      {opts, _} = Mix.Tasks.Six.split_args(["--minimum-coverage", "85.5"])
      assert opts[:minimum_coverage] == 85.5
    end

    test "passes through args after --" do
      {opts, test_args} = Mix.Tasks.Six.split_args(["--threshold", "80", "--", "--only", "unit"])
      assert opts[:threshold] == 80
      assert test_args == ["--only", "unit"]
    end

    test "passes unknown switches and their values through to mix test" do
      {opts, test_args} =
        Mix.Tasks.Six.split_args(["--max-failures", "1", "--threshold", "80", "--max-cases", "4"])

      assert opts == [threshold: 80]
      assert test_args == ["--max-failures", "1", "--max-cases", "4"]
    end

    test "passes through boolean switches, = values, and file paths in order" do
      {opts, test_args} =
        Mix.Tasks.Six.split_args([
          "test/foo_test.exs:12",
          "--trace",
          "-t",
          "75",
          "--seed=0",
          "--exclude",
          "slow",
          "--skip",
          "gen/"
        ])

      assert opts == [threshold: 75, skip: "gen/"]
      assert test_args == ["test/foo_test.exs:12", "--trace", "--seed=0", "--exclude", "slow"]
    end

    test "passes args after -- through untouched, even six options" do
      {opts, test_args} =
        Mix.Tasks.Six.split_args(["--max-failures", "1", "--", "--threshold", "80", "--"])

      assert opts == []
      assert test_args == ["--max-failures", "1", "--threshold", "80", "--"]
    end

    test "raises on an invalid value for a six option" do
      assert_raise Mix.Error, ~s(Invalid value for --threshold: "abc"), fn ->
        Mix.Tasks.Six.split_args(["--threshold", "abc"])
      end
    end

    test "raises on a missing value for a six option" do
      assert_raise Mix.Error, "Missing value for --output-dir", fn ->
        Mix.Tasks.Six.split_args(["--max-failures", "1", "--output-dir"])
      end
    end

    test "handles no args" do
      {opts, test_args} = Mix.Tasks.Six.split_args([])
      assert opts == []
      assert test_args == []
    end

    test "handles aliases" do
      {opts, _} = Mix.Tasks.Six.split_args(["-t", "75", "-o", "out"])
      assert opts[:threshold] == 75
      assert opts[:output_dir] == "out"
    end

    test "parses --import-cover option" do
      {opts, _} = Mix.Tasks.Six.split_args(["--import-cover", "cover/partitions"])
      assert opts[:import_cover] == "cover/partitions"
    end

    test "combines --import-cover with other options" do
      {opts, _} = Mix.Tasks.Six.split_args(["--import-cover", "cover/", "--threshold", "80"])
      assert opts[:import_cover] == "cover/"
      assert opts[:threshold] == 80
    end
  end

  describe "merge_cli_opts" do
    test "merges threshold into summary" do
      result = Mix.Tasks.Six.merge_cli_opts([], threshold: 80)
      assert result[:summary][:threshold] == 80
    end

    test "merges output_dir" do
      result = Mix.Tasks.Six.merge_cli_opts([], output_dir: "custom")
      assert result[:output_dir] == "custom"
    end

    test "merges skip" do
      result = Mix.Tasks.Six.merge_cli_opts([], skip: "generated/", skip: "_pb.ex")
      assert Keyword.get_values(result, :skip) == ["generated/", "_pb.ex"]
    end

    test "merges minimum coverage" do
      result = Mix.Tasks.Six.merge_cli_opts([], minimum_coverage: 88.2)
      assert result[:minimum_coverage] == 88.2
    end

    test "ignores unknown opts" do
      result = Mix.Tasks.Six.merge_cli_opts([existing: true], unknown: "val")
      assert result[:existing] == true
    end
  end
end

defmodule Mix.Tasks.Six.DetailTest do
  use ExUnit.Case

  test "split_args parses filter option" do
    {opts, test_args} = Mix.Tasks.Six.Detail.split_args(["--filter", "auth"])
    assert opts[:filter] == "auth"
    assert test_args == []
  end

  test "split_args leaves -- and the args after it for mix six" do
    {opts, rest} = Mix.Tasks.Six.Detail.split_args(["--filter", "auth", "--", "--seed", "0"])
    assert opts[:filter] == "auth"
    assert rest == ["--", "--seed", "0"]
  end

  test "split_args leaves mix six and mix test options in place" do
    {opts, rest} =
      Mix.Tasks.Six.Detail.split_args(["--threshold", "80", "-f", "auth", "--max-failures", "1"])

    assert opts == [filter: "auth"]
    assert rest == ["--threshold", "80", "--max-failures", "1"]
    assert Mix.Tasks.Six.split_args(rest) == {[threshold: 80], ["--max-failures", "1"]}
  end

  test "split_args handles alias" do
    {opts, _} = Mix.Tasks.Six.Detail.split_args(["-f", "stats"])
    assert opts[:filter] == "stats"
  end
end

defmodule Mix.Tasks.Six.HtmlTest do
  use ExUnit.Case

  test "split_args parses output-dir and open" do
    {opts, _} = Mix.Tasks.Six.Html.split_args(["--output-dir", "reports", "--open"])
    assert opts[:output_dir] == "reports"
    assert opts[:open] == true
  end

  test "split_args leaves -- and the args after it for mix six" do
    {_, rest} = Mix.Tasks.Six.Html.split_args(["--", "--only", "integration"])
    assert rest == ["--", "--only", "integration"]
  end

  test "split_args leaves mix six and mix test options in place" do
    {opts, rest} = Mix.Tasks.Six.Html.split_args(["--open", "--max-cases", "2", "-t", "70"])
    assert opts == [open: true]
    assert rest == ["--max-cases", "2", "-t", "70"]
  end
end
