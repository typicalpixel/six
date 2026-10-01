defmodule Mix.Tasks.Six.Html do
  @shortdoc "Runs tests with coverage and generates HTML report"
  @moduledoc """
  Generates an HTML coverage report at `.six/coverage.html`.

      mix six.html [options] [mix six options] [mix test options]

  ## Options

    * `--output-dir DIR` - Output directory (default: .six/)
    * `--open` - Open the report in the default browser after generation

  All other arguments are handled as in `mix six`.
  """

  use Mix.Task

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @six :ignore
  @impl true
  def run(args) do
    {opts, rest} = split_args(args)

    # Save original formatters so we can restore after the run
    original = Application.get_env(:six, :formatters)

    # Ensure HTML formatter is included
    current =
      Application.get_env(:six, :formatters, [Six.Formatters.Terminal, Six.Formatters.Agent])

    unless Six.Formatters.HTML in current do
      Application.put_env(:six, :formatters, current ++ [Six.Formatters.HTML])
    end

    if dir = opts[:output_dir] do
      Application.put_env(:six, :output_dir, dir)
    end

    Mix.Tasks.Six.run(rest)

    # Restore original formatters to avoid polluting the application env
    case original do
      nil -> Application.delete_env(:six, :formatters)
      val -> Application.put_env(:six, :formatters, val)
    end

    if opts[:open] do
      output_dir = opts[:output_dir] || Application.get_env(:six, :output_dir, ".six")
      path = Path.join(output_dir, "coverage.html")
      open_browser(path)
    end
  end

  @doc false
  # Strips this task's own options and leaves the rest, including `--` and
  # anything after it, for `mix six` to handle.
  def split_args(args) do
    Mix.Tasks.Six.extract_opts(args, [output_dir: :string, open: :boolean], o: :output_dir)
  end

  @six :ignore
  defp open_browser(path) do
    abs_path = Path.expand(path)

    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [abs_path])
      {:unix, _} -> System.cmd("xdg-open", [abs_path])
      {:win32, _} -> System.cmd("cmd", ["/c", "start", abs_path])
    end
  end
end
