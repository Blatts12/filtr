defmodule Filtr.Processor.Default do
  @moduledoc """
  Resolves the `default` declared for a key.

  A default can be a plain term, a zero arity function, or a function of one
  argument that receives the current context. Internal module, the API may
  change between releases.
  """

  alias Filtr.Types

  @spec get_default(Types.key_schema(), Types.context()) :: Types.value()
  def get_default(%{default: default_value}, context), do: default(default_value, context)
  def get_default(_key_schema, _context), do: nil

  defp default(:__none__, _context), do: nil
  defp default(default_fn, _context) when is_function(default_fn, 0), do: default_fn.()
  defp default(default_fn, context) when is_function(default_fn, 1), do: default_fn.(context)
  defp default(default_value, _context), do: default_value
end
