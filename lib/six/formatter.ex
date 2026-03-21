defmodule Six.Formatter do
  @moduledoc """
  Behaviour for Six coverage output formatters.
  """

  @type summary :: map()

  @callback format(summary(), keyword()) :: :ok | {:error, term()}

  @doc """
  Optional callback for formatters that produce files.
  Returns the path to the generated file.
  """
  @callback output_path(keyword()) :: String.t() | nil
  @optional_callbacks [output_path: 1]
end
