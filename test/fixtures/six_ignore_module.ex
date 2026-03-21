defmodule Six.Fixtures.SixIgnoreModule do
  use Six

  def normal_function do
    :covered
  end

  @six :ignore
  def excluded_function do
    complex_setup()
    more_stuff()
    :excluded
  end

  @six :ignore
  def one_liner, do: :excluded

  @six :ignore
  @doc "This has a doc between attribute and def"
  def excluded_with_doc do
    :also_excluded
  end

  def another_normal do
    :covered
  end

  defp complex_setup, do: :setup
  defp more_stuff, do: :stuff
end
