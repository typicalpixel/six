defmodule Mix.Tasks.Six do
  @shortdoc "Runs tests with coverage analysis"
  @moduledoc """
  Runs `mix test --cover` with Six as the coverage tool.

      mix six [options] [mix test options]

  ## Options

    * `--threshold N` - Report threshold for formatter output (default: 90)
    * `--minimum-coverage N` - Fail if total coverage drops below N
    * `--output-dir DIR` - Output directory (default: .six/)
    * `--skip FILE` - Additional file pattern to skip (repeatable)
    * `--track-ignores` - Write a `.sixignore` file at the project root
      tracking all explicit coverage exclusions. Commit this file to
      review ignore changes in PRs.
    * `--import-cover DIR` - Import .coverdata files from DIR and generate
      a report without running tests. Used to merge coverage from
      partitioned CI runs.

  Any other arguments are passed through to `mix test`, so its options and
  file paths work as usual:

      mix six --threshold 90 --max-failures 1 --max-cases 4
      mix six test/my_app/accounts_test.exs:42

  Arguments after `--` are always passed to `mix test` untouched.
  """

  use Mix.Task

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @switches [
    threshold: :integer,
    minimum_coverage: :float,
    output_dir: :string,
    skip: :keep,
    track_ignores: :boolean,
    import_cover: :string
  ]
  @aliases [t: :threshold, o: :output_dir]

  @six :ignore
  @impl true
  def run(args) do
    {opts, test_args} = split_args(args)

    Mix.env(:test)

    with_track_ignores(opts, fn ->
      if import_dir = opts[:import_cover] do
        import_and_report(import_dir, opts)
      else
        run_tests(opts, test_args)
      end
    end)
  end

  @six :ignore
  defp with_track_ignores(opts, fun) do
    if Keyword.get(opts, :track_ignores) do
      original = Application.get_env(:six, :track_ignores)
      Application.put_env(:six, :track_ignores, true)

      try do
        fun.()
      after
        case original do
          nil -> Application.delete_env(:six, :track_ignores)
          val -> Application.put_env(:six, :track_ignores, val)
        end
      end
    else
      fun.()
    end
  end

  @six :ignore
  defp run_tests(opts, test_args) do
    project = Mix.Project.config()
    test_coverage = Keyword.get(project, :test_coverage, [])
    test_coverage = Keyword.put(test_coverage, :tool, Six)
    test_coverage = merge_cli_opts(test_coverage, opts)

    Application.put_env(:mix, :test_coverage, test_coverage)

    Mix.Task.run("test", ["--cover" | test_args])
  end

  @six :ignore
  defp import_and_report(dir, opts) do
    unless File.dir?(dir) do
      Mix.raise("--import-cover directory does not exist: #{dir}")
    end

    :cover.start()

    compile_path = Mix.Project.compile_path()
    Six.Cover.compile_modules(compile_path)

    {imported, errors} = Six.Cover.import_all_coverdata(dir)

    Enum.each(errors, fn {file, reason} ->
      IO.warn("Failed to import #{file}: #{inspect(reason)}")
    end)

    if imported == 0 do
      Mix.raise("No .coverdata files found in #{dir}")
    end

    IO.puts("Imported #{imported} coverdata file(s) from #{dir}")

    Six.Report.run(opts)
  end

  @doc false
  def split_args(args) do
    {opts, rest} = extract_opts(args, @switches, @aliases)
    {opts, List.delete(rest, "--")}
  end

  @doc false
  # Pulls the given switches out of `args`, stopping at `--`. Everything else
  # (unknown switches and their values, test file paths, and `--` along with
  # whatever follows it) is returned untouched and in order, so it can be
  # handed on to `mix test`.
  def extract_opts(args, switches, aliases) do
    do_extract_opts(args, [strict: switches, aliases: aliases], [], [])
  end

  defp do_extract_opts(args, parser_opts, opts, rest) do
    case OptionParser.next(args, parser_opts) do
      {:ok, key, value, tail} ->
        do_extract_opts(tail, parser_opts, [{key, value} | opts], rest)

      {:invalid, switch, nil, _tail} ->
        Mix.raise("Missing value for #{switch}")

      {:invalid, switch, value, _tail} ->
        Mix.raise("Invalid value for #{switch}: #{inspect(value)}")

      {:undefined, _switch, _value, tail} ->
        consumed = Enum.take(args, length(args) - length(tail))
        do_extract_opts(tail, parser_opts, opts, Enum.reverse(consumed, rest))

      {:error, ["--" | _] = tail} ->
        {Enum.reverse(opts), Enum.reverse(rest, tail)}

      {:error, [arg | tail]} ->
        do_extract_opts(tail, parser_opts, opts, [arg | rest])

      {:error, []} ->
        {Enum.reverse(opts), Enum.reverse(rest)}
    end
  end

  @doc false
  def merge_cli_opts(test_coverage, opts) do
    Enum.reduce(opts, test_coverage, fn
      {:threshold, val}, acc ->
        summary = Keyword.get(acc, :summary, [])
        Keyword.put(acc, :summary, Keyword.put(summary, :threshold, val))

      {:minimum_coverage, val}, acc ->
        Keyword.put(acc, :minimum_coverage, val)

      {:output_dir, val}, acc ->
        Keyword.put(acc, :output_dir, val)

      {:skip, val}, acc ->
        acc ++ [skip: val]

      _, acc ->
        acc
    end)
  end
end
