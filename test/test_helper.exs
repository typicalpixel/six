# Fixture modules that must be loaded with a real source path (for
# Six.Cover.module_path/1). Compile once here so individual tests don't
# redefine them.
Code.compile_file("test/fixtures/multi_module.ex")

ExUnit.start(exclude: [:coverdata])
