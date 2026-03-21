defmodule Six.Cover do
  @moduledoc false

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @doc """
  Compiles all .beam files in the given path for coverage tracking.
  Cannot be tested during a coverage run — calls :cover.compile_beam.
  """
  @six :ignore
  def compile_modules(compile_path) do
    beams =
      compile_path
      |> Path.join("*.beam")
      |> Path.wildcard()

    modules =
      Enum.flat_map(beams, fn beam ->
        case :cover.compile_beam(String.to_charlist(beam)) do
          {:ok, module} -> [module]
          {:error, _reason} -> []
        end
      end)

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
  """
  def analyze_all do
    :cover.modules()
    |> Enum.reduce(%{}, fn module, acc ->
      case analyze(module) do
        {:ok, results} -> Map.put(acc, module, results)
        # six:ignore:next
        {:error, _} -> acc
      end
    end)
  end

  @doc """
  Resolves the source file path for a module, relative to the project root.
  Returns nil if the source file doesn't exist.
  """
  def module_path(module) do
    case module.module_info(:compile)[:source] do
      # six:ignore:next
      nil ->
        nil

      source ->
        path = to_string(source)

        if File.exists?(path) do
          Path.relative_to(path, File.cwd!())
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
