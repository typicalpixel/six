defmodule Six.Fixtures.IgnoreModule do
  def covered do
    :ok
  end

  # six:ignore:start
  def ignored do
    :should_be_nil
  end

  # six:ignore:stop

  def also_covered do
    # six:ignore:next
    :this_line_ignored
    :this_line_counted
  end
end
