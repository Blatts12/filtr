defmodule Filtr.Processor do
  @moduledoc false

  alias Filtr.Processor.Cast
  alias Filtr.Processor.Context
  alias Filtr.Processor.Validate
  alias Filtr.Processor.Value
  alias Filtr.Types

  @spec run(schema :: Types.schema(), params :: Types.params()) :: Types.result()
  @spec run(schema :: Types.schema(), params :: Types.params(), opts :: Types.opts()) ::
          Types.result()
  def run(schema, params, opts \\ []) do
    context = Context.create_context(params, opts)

    schema
    |> process(context)
    |> Context.to_result()
  end

  defp process(schema, context) do
    :maps.fold(&process_entry/3, context, schema)
  end

  defp process_entry(key, %{type: nested_schema} = key_schema, context)
       when is_map(nested_schema) do
    value = Context.get_param(context, key)

    if missing_key?(key_schema, value) do
      resolve_missing(key, key_schema, context)
    else
      nested_context = process_nested(nested_schema, value, context)
      Context.put_nested_result(context, key, nested_context)
    end
  end

  defp process_entry(key, %{type: {:list, _type}} = key_schema, context) do
    value = Context.get_param(context, key)

    if missing_key?(key_schema, value) do
      resolve_missing(key, key_schema, context)
    else
      process_list(key, key_schema, value, context)
    end
  end

  defp process_entry(key, %{type: _type} = key_schema, context) do
    Value.process_param(key, key_schema, context)
  end

  # A list or nested-map key only needs the required/default treatment that scalar
  # keys already get when the param is absent and the schema asks for one.
  defp missing_key?(%{required: true}, value) when value in [:__none__, nil], do: true
  defp missing_key?(%{default: _}, value) when value in [:__none__, nil], do: true

  defp missing_key?(_key_schema, _value), do: false

  defp resolve_missing(key, key_schema, context) do
    result =
      key
      |> Validate.validate(key_schema, :__none__, context)
      |> Value.to_proper()

    Context.put_result(context, key, result)
  end

  defp process_nested(schema, params, context) do
    params = Value.fallback_map(params, nil)
    context = %{context | result: [], params: params}

    process(schema, context)
  end

  defp process_list(key, %{type: {:list, item_type}} = key_schema, value, context) do
    {result, valid?} = reduce_items(value, item_fun(key, key_schema, item_type, context))
    put_list_result(context, key, result, valid?)
  end

  defp item_fun(_key, _key_schema, nested_schema, context) when is_map(nested_schema) do
    fn item ->
      %{result: result, valid?: valid?} = process_nested(nested_schema, item, context)
      {:maps.from_list(result), valid?}
    end
  end

  defp item_fun(key, key_schema, {:list, inner_type}, context) do
    inner_fun = item_fun(key, key_schema, inner_type, context)
    fn item -> reduce_items(item, inner_fun) end
  end

  defp item_fun(key, key_schema, item_type, context) do
    item_schema = %{key_schema | type: item_type}
    fn item -> process_item(key, item_schema, item, context) end
  end

  defp process_item(key, item_schema, value, context) do
    result =
      case Cast.cast(key, item_schema, value, context) do
        {:ok, {:default, value}} ->
          value

        {:ok, casted} ->
          key
          |> Validate.validate(item_schema, casted, context)
          |> Value.to_proper()

        error ->
          error
      end

    {result, Value.valid_value?(result)}
  end

  defp reduce_items(values, fun) when is_list(values) do
    {results, valid?} =
      Enum.reduce(values, {[], true}, fn item, {acc, acc_valid?} ->
        {result, item_valid?} = fun.(item)
        {[result | acc], acc_valid? and item_valid?}
      end)

    {Enum.reverse(results), valid?}
  end

  # Phoenix parses items[0][name] into a map keyed by index, so the keys have to be sorted
  # numerically.
  defp reduce_items(values, fun) when is_map(values) do
    indexed = Enum.map(values, fn {key, value} -> {index_key(key), value} end)
    sorted = :lists.keysort(1, indexed)

    sorted
    |> Enum.map(fn {_index, value} -> value end)
    |> reduce_items(fun)
  end

  defp reduce_items(_values, _fun), do: {[], true}

  defp index_key(key) when is_integer(key), do: key

  defp index_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {index, ""} -> index
      _ -> key
    end
  end

  defp index_key(key), do: key

  defp put_list_result(context, key, result, valid?) do
    result_list = [{key, result} | context.result]
    %{context | result: result_list, valid?: context.valid? and valid?}
  end
end
