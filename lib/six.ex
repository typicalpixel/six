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
  """
  @six :ignore
  def start(compile_path, opts \\ []) do
    :cover.start()

    {:ok, _modules} = Six.Cover.compile_modules(compile_path)

    fn -> report(opts) end
  end

  @six :ignore
  defp report(opts) do
    Six.Report.run(opts)
  end
end
