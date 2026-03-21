defmodule Mix.Tasks.Six.Detail do
  @shortdoc "Runs tests with coverage analysis and source-level detail"
  @moduledoc """
  Same as `mix six` but includes source-level annotation output.

      mix six.detail [--filter PATTERN] [-- test_args]

  ## Options

    * `--filter PATTERN` - Only show source detail for files matching pattern
  """

  use Mix.Task

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @six :ignore
  @impl true
  def run(args) do
    {opts, test_args} = split_args(args)

    Application.put_env(:six, :detail, true)

    if filter = opts[:filter] do
      Application.put_env(:six, :filter, filter)
    end

    Mix.Tasks.Six.run(test_args)
  end

  @doc false
  def split_args(args) do
    {args_before, args_after} =
      case Enum.split_while(args, &(&1 != "--")) do
        {before, ["--" | after_]} -> {before, after_}
        {before, []} -> {before, []}
      end

    {parsed, _, _} =
      OptionParser.parse(args_before,
        strict: [filter: :string],
        aliases: [f: :filter]
      )

    {parsed, args_after}
  end
end
