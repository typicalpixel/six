defmodule Six.Fixtures.SampleModule do
  def covered_function do
    :ok
  end

  def uncovered_function do
    :not_called
  end

  def branching_function(x) do
    case x do
      :ok -> :handled
      :error -> :failed
    end
  end
end
