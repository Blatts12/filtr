defmodule Filtr.Processor.Default do
  @moduledoc false

  alias Filtr.Types

  @spec get_default(key_schema :: Types.key_schema(), context :: Types.context()) :: Types.value()
  def get_default(key_schema, context) do
    default_value = Map.get(key_schema, :default, :__none__)
    default(default_value, context)
  end

  defp default(:__none__, _context), do: nil
  defp default(default_fn, _context) when is_function(default_fn, 0), do: default_fn.()
  defp default(default_fn, context) when is_function(default_fn, 1), do: default_fn.(context)
  defp default(default_value, _context), do: default_value
end
