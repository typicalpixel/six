defmodule Six.Cover do
  @moduledoc false

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @doc """
  Compiles all .beam files in the given path for coverage tracking.
  Cannot be tested during a coverage run — calls :cover.compile_beam.

  Passes the whole list in one call — :cover parallelizes list compiles
  internally, where per-file calls serialize through its gen_server.
  """
  @six :ignore
  def compile_modules(compile_path) do
    beams =
      compile_path
      |> Path.join("*.beam")
      |> Path.wildcard()
      |> Enum.map(&String.to_charlist/1)

    modules =
      case :cover.compile_beam(beams) do
        results when is_list(results) ->
          for {:ok, module} <- results, do: module

        {:error, _reason} ->
          []
      end

    {:ok, modules}
  end

  @doc """
  Analyzes a single module for line-level coverage.
  """
  def analyze(module) do
    case :cover.analyse(module, :calls, :line) do
      {:ok, results} ->
        {:ok, results}

      # six:ignore:start
      {:error, :not_cover_compiled} ->
        {:error, :not_cover_compiled}

      {:error, reason} ->
        {:error, reason}
        # six:ignore:stop
    end
  end

  @doc """
  Analyzes all cover-compiled modules. Returns a map of module => results.

  Uses a single batched `:cover.analyse/2` call rather than one call per
  module — the cover server is a lone gen_server, so per-module calls
  serialize into thousands of round trips on large projects.
  """
  def analyze_all do
    case :cover.analyse(:calls, :line) do
      {:result, results, _failed} ->
        Enum.group_by(results, fn {{module, _line}, _count} -> module end)

      # six:ignore:start
      {:error, _reason} ->
        %{}
        # six:ignore:stop
    end
  end

  @doc """
  Analyzes a single module for per-function call counts.
  Returns `{:ok, [{{mod, fun, arity}, count}]}` or `{:error, reason}`.
  """
  def analyze_functions(module) do
    case :cover.analyse(module, :calls, :function) do
      {:ok, results} ->
        {:ok, results}

      # six:ignore:start
      {:error, reason} ->
        {:error, reason}
        # six:ignore:stop
    end
  end

  @doc """
  Analyzes per-function call counts for all cover-compiled modules.
  Returns a map of module => [{{mod, fun, arity}, count}].

  Batched for the same reason as `analyze_all/0`.
  """
  def analyze_all_functions do
    case :cover.analyse(:calls, :function) do
      {:result, results, _failed} ->
        Enum.group_by(results, fn {{module, _fun, _arity}, _count} -> module end)

      # six:ignore:start
      {:error, _reason} ->
        %{}
        # six:ignore:stop
    end
  end

  @doc """
  Resolves the source file path for a module, relative to the project root.
  Returns nil if the source file doesn't exist.

  Pass `cwd` when resolving many modules to avoid a `File.cwd!` syscall per
  module.
  """
  def module_path(module, cwd \\ nil) do
    case module.module_info(:compile)[:source] do
      # six:ignore:next
      nil ->
        nil

      source ->
        path = to_string(source)

        if File.exists?(path) do
          Path.relative_to(path, cwd || File.cwd!())
        else
          nil
        end
    end
  rescue
    _ -> nil
  end

  @doc """
  Imports a single .coverdata file into the current cover session.
  Returns :ok or {:error, reason}.
  Cannot be tested during a coverage run — mutates :cover state.
  """
  @six :ignore
  def import_coverdata(path) do
    case :cover.import(String.to_charlist(path)) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  catch
    :exit, reason -> {:error, reason}
  end

  @doc """
  Imports all .coverdata files from a directory.
  Returns {imported_count, errors}.
  Cannot be tested during a coverage run — mutates :cover state.
  """
  @six :ignore
  def import_all_coverdata(dir) do
    files =
      dir
      |> Path.join("*.coverdata")
      |> Path.wildcard()

    {imported, errors} =
      Enum.reduce(files, {0, []}, fn file, {count, errs} ->
        case import_coverdata(file) do
          :ok -> {count + 1, errs}
          {:error, reason} -> {count, [{file, reason} | errs]}
        end
      end)

    {imported, Enum.reverse(errors)}
  end

  @doc """
  Stops the cover tool. Cannot be tested during a coverage run.
  """
  @six :ignore
  def stop do
    :cover.stop()
  end
end
