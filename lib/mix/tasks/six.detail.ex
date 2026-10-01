defmodule Mix.Tasks.Six.Detail do
  @shortdoc "Runs tests with coverage analysis and source-level detail"
  @moduledoc """
  Same as `mix six` but includes source-level annotation output.

      mix six.detail [--filter PATTERN] [mix six options] [mix test options]

  ## Options

    * `--filter PATTERN` - Only show source detail for files matching pattern

  All other arguments are handled as in `mix six`.
  """

  use Mix.Task

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @six :ignore
  @impl true
  def run(args) do
    {opts, rest} = split_args(args)

    Application.put_env(:six, :detail, true)

    if filter = opts[:filter] do
      Application.put_env(:six, :filter, filter)
    end

    Mix.Tasks.Six.run(rest)
  end

  @doc false
  # Strips this task's own options and leaves the rest, including `--` and
  # anything after it, for `mix six` to handle.
  def split_args(args) do
    Mix.Tasks.Six.extract_opts(args, [filter: :string], f: :filter)
  end
end
