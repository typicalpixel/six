defmodule Mix.Tasks.Six.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc do
    "Installs Six as the test coverage tool"
  end

  @spec example() :: String.t()
  def example do
    "mix igniter.install six --threshold 90 --minimum-coverage 85 --skip generated/ --track-ignores"
  end

  @spec long_doc() :: String.t()
  def long_doc do
    """
    #{short_doc()}

    Sets `test_coverage: [tool: Six]` in `project/0` of `mix.exs` and makes
    `mix six`, `mix six.detail` and `mix six.html` run in the `:test`
    environment via `preferred_envs` in `cli/0`.

    Any options given are written to `config/test.exs` as `config :six`.

    ## Example

    ```sh
    #{example()}
    ```

    ## Options

    * `--threshold N` or `-t N` - Report threshold for formatter output
    * `--minimum-coverage N` - Fail if total coverage drops below N
    * `--output-dir DIR` or `-o DIR` - Output directory
    * `--skip PATTERN` - File pattern (a regex) to skip entirely (repeatable)
    * `--track-ignores` - Write a `.sixignore` manifest at the project root
      tracking all exclusions
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Six.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @preferred_envs [:six, :"six.detail", :"six.html"]

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :six,
        example: __MODULE__.Docs.example(),
        only: [:test],
        schema: [
          threshold: :float,
          minimum_coverage: :float,
          output_dir: :string,
          skip: :keep,
          track_ignores: :boolean
        ],
        aliases: [t: :threshold, o: :output_dir]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      opts = igniter.args.options

      igniter
      |> Igniter.Project.MixProject.update(:project, [:test_coverage, :tool], fn _ ->
        {:ok, {:code, Six}}
      end)
      |> add_preferred_envs()
      |> configure(:threshold, opts[:threshold])
      |> configure(:minimum_coverage, opts[:minimum_coverage])
      |> configure(:output_dir, opts[:output_dir])
      |> configure_skip_files(List.wrap(opts[:skip]))
      |> configure(:track_ignores, opts[:track_ignores])
      |> update_gitignore(opts[:output_dir] || ".six")
    end

    defp add_preferred_envs(igniter) do
      Enum.reduce(@preferred_envs, igniter, fn task, igniter ->
        Igniter.Project.MixProject.update(igniter, :cli, [:preferred_envs, task], fn _ ->
          {:ok, {:code, :test}}
        end)
      end)
    end

    @gitignore_comment ~s(# If you run "mix test --cover", coverage assets end up here.)

    defp update_gitignore(igniter, output_dir) do
      if Igniter.exists?(igniter, ".gitignore") do
        igniter
        |> Igniter.include_existing_file(".gitignore")
        |> Igniter.update_file(".gitignore", fn source ->
          Rewrite.Source.update(source, :content, &add_ignores(&1, output_dir))
        end)
      else
        igniter
      end
    end

    # Puts the six output directory right after `/cover/` when it is there,
    # otherwise appends both under the comment `mix new` uses.
    defp add_ignores(content, output_dir) do
      entry = "/" <> String.trim(output_dir, "/") <> "/"
      lines = String.split(content, "\n")

      cond do
        ignored?(lines, entry) ->
          content

        ignored?(lines, "/cover/") ->
          lines
          |> Enum.flat_map(&if(ignored?([&1], "/cover/"), do: [&1, entry], else: [&1]))
          |> Enum.join("\n")

        true ->
          String.trim_trailing(content) <> "\n\n#{@gitignore_comment}\n/cover/\n#{entry}\n"
      end
    end

    defp ignored?(lines, entry) do
      bare = String.trim(entry, "/")
      Enum.any?(lines, &(String.trim(&1) |> String.trim("/") == bare))
    end

    defp configure(igniter, _key, nil), do: igniter

    defp configure(igniter, key, value) do
      Igniter.Project.Config.configure(igniter, "test.exs", :six, [key], value)
    end

    defp configure_skip_files(igniter, []), do: igniter

    # `mix six --skip` compiles each pattern as a regex, so write them as
    # regex sigils to keep the same matching behaviour.
    defp configure_skip_files(igniter, patterns) do
      code =
        patterns
        |> Enum.map_join(", ", &inspect(Regex.compile!(&1)))
        |> then(&Sourceror.parse_string!("[#{&1}]"))

      configure(igniter, :skip_files, {:code, code})
    end
  end
else
  defmodule Mix.Tasks.Six.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'six.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
