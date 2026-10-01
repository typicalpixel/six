defmodule Six do
  @moduledoc """
  Zero-dependency Elixir coverage tool built for AI-assisted development.

  ## Usage

  Add to your `mix.exs`:

      def project do
        [
          test_coverage: [tool: Six],
          # ...
        ]
      end

  Then run:

      mix test --cover

  This produces a terminal summary and an agent-readable report at `.six/coverage.md`.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :six, accumulate: true)
    end
  end

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @doc """
  Called by Mix when `test_coverage: [tool: Six]` is configured.
  Starts the cover tool and returns a function to run after tests complete.

  When Mix asks for an export (`--export-coverage NAME`, or `--partitions`
  with `MIX_TEST_PARTITION` set), coverage is written to
  `<output>/<name>.coverdata` instead of being reported, ready for
  `mix six --import-cover`.
  """
  @six :ignore
  def start(compile_path, opts \\ []) do
    :cover.start()

    {:ok, _modules} = Six.Cover.compile_modules(compile_path)

    if name = opts[:export] do
      fn -> export(name, opts) end
    else
      fn -> report(opts) end
    end
  end

  @six :ignore
  defp export(name, opts) do
    dir = Keyword.get(opts, :output, "cover")
    path = Path.join(dir, "#{name}.coverdata")

    case Six.Cover.export_coverdata(path) do
      :ok ->
        IO.puts("Coverage exported to #{path}")
        IO.puts("Run `mix six --import-cover #{dir}` once all exports complete")

      {:error, reason} ->
        Mix.raise("Failed to export coverage to #{path}: #{inspect(reason)}")
    end
  end

  @six :ignore
  defp report(opts) do
    Six.Report.run(opts)
  end
end
