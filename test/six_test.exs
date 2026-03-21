defmodule SixTest do
  use ExUnit.Case

  test "module is available" do
    assert Code.ensure_loaded?(Six)
  end

  test "use Six allows @six :ignore without compiler warnings" do
    # Compile the fixture that uses `use Six` + `@six :ignore`.
    # If the macro didn't register the attribute, compilation would warn.
    [{module, _}] = Code.compile_file("test/fixtures/six_ignore_module.ex")
    assert module == Six.Fixtures.SixIgnoreModule
    assert module.normal_function() == :covered
    assert module.another_normal() == :covered
  end
end
