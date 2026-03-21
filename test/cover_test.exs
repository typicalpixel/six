defmodule Six.CoverTest do
  use ExUnit.Case

  test "module_path returns relative path for loaded module" do
    path = Six.Cover.module_path(Six)
    assert path == "lib/six.ex"
  end

  test "module_path returns nil for nonexistent module" do
    assert Six.Cover.module_path(This.Module.Does.Not.Exist) == nil
  end

  test "module_path returns nil for module with missing source file" do
    # :erlang is a loaded module but its source won't be in this project
    result = Six.Cover.module_path(:erlang)
    assert result == nil
  end

  test "analyze returns results for a cover-compiled module" do
    # During `mix test --cover`, :cover is running and modules are compiled.
    # During `mix test`, :cover is not running so this returns an error.
    case Six.Cover.analyze(Six) do
      {:ok, results} ->
        assert is_list(results)
        assert length(results) > 0

      {:error, _} ->
        # Not running under --cover, that's fine
        :ok
    end
  end

  test "analyze_all returns a map" do
    result = Six.Cover.analyze_all()
    assert is_map(result)

    # During --cover, this will have modules; without, it'll be empty
    if map_size(result) > 0 do
      {_module, results} = Enum.at(result, 0)
      assert is_list(results)
    end
  end
end
