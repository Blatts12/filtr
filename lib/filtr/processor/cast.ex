defmodule Filtr.Processor.Cast do
  @moduledoc false

  import Filtr.Processor.Opaque, only: [is_opaque: 1]

  alias Filtr.Processor.Context
  alias Filtr.Processor.Error
  alias Filtr.Types

  @spec cast(
          key :: Types.key(),
          key_schema :: Types.key_schema(),
          param :: term(),
          context :: Types.context()
        ) :: {:ok, term()} | {:error, term()}
  def cast(_key, _key_schema, :__none__, _context), do: {:ok, :__none__}
  def cast(_key, %{type: opaque}, param, _context) when is_opaque(opaque), do: {:ok, param}

  def cast(key, %{type: cast_fn} = key_schema, param, context) when is_function(cast_fn, 3) do
    param
    |> cast_fn.(key_schema, context)
    |> cast_result(key, key_schema, context)
  end

  def cast(key, %{type: cast_fn} = key_schema, param, context) when is_function(cast_fn, 2) do
    param
    |> cast_fn.(context)
    |> cast_result(key, key_schema, context)
  end

  def cast(key, %{type: cast_fn} = key_schema, param, context) when is_function(cast_fn, 1) do
    param
    |> cast_fn.()
    |> cast_result(key, key_schema, context)
  end

  def cast(key, key_schema, param, context) do
    plugin_cast(param, key, key_schema, context)
  end

  defp plugin_cast(nil, key, key_schema, context), do: cast_result(nil, key, key_schema, context)

  defp plugin_cast(param, key, %{type: type} = key_schema, context) do
    plugin = Context.plugin_for_type(context, type)

    if plugin do
      result = plugin.cast(param, type, context)
      cast_result(result, key, key_schema, context)
    else
      cast_result({:error, "missing plugin for type #{type}"}, key, key_schema, context)
    end
  end

  defp cast_result(:not_handled, key, key_schema, context), do: Error.not_handled(key, key_schema, context, "cast")
  defp cast_result({:error, errors}, key, key_schema, context), do: Error.handle_error(errors, key, key_schema, context)
  defp cast_result({:ok, casted_value}, _key, _key_schema, _context), do: {:ok, casted_value}
  defp cast_result(casted_value, _key, _key_schema, _context), do: {:ok, casted_value}
end
