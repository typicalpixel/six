defmodule Mix.Tasks.Six.InstallTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  defp install(igniter \\ test_project(), args) do
    igniter
    |> Igniter.compose_task("six.install", args)
    |> apply_igniter!()
  end

  # `apply_igniter!` only reloads Elixir sources, so dotfiles like
  # `.gitignore` are read from the test project's files instead.
  defp content(igniter, path) do
    case Rewrite.source(igniter.rewrite, path) do
      {:ok, source} -> Rewrite.Source.get(source, :content)
      _ -> Map.fetch!(igniter.assigns.test_files, path)
    end
  end

  test "is installed as a test-only dependency" do
    assert Mix.Tasks.Six.Install.info([], nil).only == [:test]
  end

  describe "mix.exs" do
    test "sets Six as the test coverage tool" do
      assert content(install([]), "mix.exs") =~ "test_coverage: [tool: Six]"
    end

    test "adds the six tasks to preferred_envs" do
      assert content(install([]), "mix.exs") =~
               ~s(preferred_envs: [six: :test, "six.detail": :test, "six.html": :test])
    end

    test "keeps existing test_coverage and preferred_envs entries" do
      mix_exs = """
      defmodule Test.MixProject do
        use Mix.Project

        def project do
          [app: :test, test_coverage: [summary: false]]
        end

        def cli do
          [preferred_envs: [credo: :test]]
        end
      end
      """

      mix_exs = install(test_project(files: %{"mix.exs" => mix_exs}), []) |> content("mix.exs")

      assert mix_exs =~ "test_coverage: [summary: false, tool: Six]"
      assert mix_exs =~ ~s(credo: :test, six: :test, "six.detail": :test, "six.html": :test)
    end

    test "is idempotent" do
      test_project()
      |> Igniter.compose_task("six.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("six.install", [])
      |> assert_unchanged()
    end
  end

  describe "config/test.exs" do
    test "is not touched without options" do
      install([]) |> assert_unchanged("config/test.exs")
    end

    test "writes the given options" do
      igniter =
        install(
          ~w(--threshold 90 --minimum-coverage 85 --skip generated/ --skip _pb.ex --track-ignores)
        )

      config = content(igniter, "config/test.exs")

      assert config =~ "config :six,"
      assert config =~ "threshold: 90.0"
      assert config =~ "minimum_coverage: 85.0"
      assert config =~ ~S"skip_files: [~r/generated\//, ~r/_pb.ex/]"
      assert config =~ "track_ignores: true"
    end

    test "writes output_dir" do
      assert content(install(~w(--output-dir cover)), "config/test.exs") =~
               ~s(config :six, output_dir: "cover")
    end

    test "supports short aliases" do
      config = content(install(~w(-t 80 -o cover)), "config/test.exs")

      assert config =~ "threshold: 80.0"
      assert config =~ ~s(output_dir: "cover")
    end

    test "skip patterns compile back to the same regexes" do
      config = content(install(["--skip", ~S"_pb\.ex$"]), "config/test.exs")

      assert config =~ ~S"skip_files: [~r/_pb\.ex$/]"
    end
  end

  describe ".gitignore" do
    test "adds .six/ right after /cover/" do
      assert content(install([]), ".gitignore") =~
               ~s(# If you run "mix test --cover", coverage assets end up here.\n/cover/\n/.six/\n)
    end

    test "uses the given output dir" do
      gitignore = content(install(~w(--output-dir coverage/six)), ".gitignore")

      assert gitignore =~ "/cover/\n/coverage/six/\n"
      refute gitignore =~ "/.six/"
    end

    test "appends both directories when /cover/ is missing" do
      gitignore =
        test_project(files: %{".gitignore" => "/_build/\n"})
        |> install([])
        |> content(".gitignore")

      assert gitignore ==
               ~s(/_build/\n\n# If you run "mix test --cover", coverage assets end up here.\n/cover/\n/.six/\n)
    end

    test "leaves an already ignored directory alone" do
      test_project(files: %{".gitignore" => "cover\n.six/\n"})
      |> Igniter.compose_task("six.install", [])
      |> assert_unchanged(".gitignore")
    end
  end
end
