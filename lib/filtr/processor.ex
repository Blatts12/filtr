defmodule Filtr.Processor do
  @moduledoc false

  alias Filtr.Processor.Cast
  alias Filtr.Processor.Context
  alias Filtr.Processor.Validate
  alias Filtr.Processor.Value
  alias Filtr.Types

  @spec run(schema :: Types.schema(), params :: Types.params()) :: Types.result()
  @spec run(schema :: Types.schema(), params :: Types.params(), opts :: Types.opts()) :: Types.result()
  def run(schema, params, opts \\ []) do
    context = Context.create_context(params, opts)

    schema
    |> process(context)
    |> Context.to_result()
  end

  defp process(schema, context) do
    :maps.fold(&process_entry/3, context, schema)
  end

  defp process_entry(key, %{type: nested_schema}, context) when is_map(nested_schema) do
    value = Context.get_param(context, key)
    nested_context = process_nested(nested_schema, value, context)
    Context.put_nested_result(context, key, nested_context)
  end

  defp process_entry(key, %{type: {:list, _type}} = key_schema, context) do
    value = Context.get_param(context, key)
    process_list(key, key_schema, value, context)
  end

  defp process_entry(key, %{type: _type} = key_schema, context) do
    Value.process_param(key, key_schema, context)
  end

  defp process_nested(schema, params, context) do
    params = Value.fallback_none(params, %{})
    context = %{context | result: [], params: params}

    process(schema, context)
  end

  defp process_list(key, key_schema, value, context) do
    {result, valid?} = list_value(key, key_schema, value, context)
    put_list_result(context, key, result, valid?)
  end

  defp list_value(_key, %{type: {:list, nested_schema}}, value, context) when is_map(nested_schema) do
    reduce_items(value, fn item ->
      %{result: result, valid?: valid?} = process_nested(nested_schema, item, context)
      {:maps.from_list(result), valid?}
    end)
  end

  defp list_value(key, %{type: {:list, {:list, _} = inner_type}} = key_schema, value, context) do
    inner_schema = %{key_schema | type: inner_type}
    reduce_items(value, fn item -> list_value(key, inner_schema, item, context) end)
  end

  defp list_value(key, %{type: {:list, type}} = key_schema, value, context) do
    item_schema = %{key_schema | type: type}
    reduce_items(value, fn item -> process_item(key, item_schema, item, context) end)
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

  defp reduce_items(values, fun) when is_map(values) do
    values
    |> Map.values()
    |> reduce_items(fun)
  end

  defp reduce_items(_values, _fun), do: {[], true}

  defp put_list_result(context, key, result, valid?) do
    result_list = [{key, result} | context.result]
    %{context | result: result_list, valid?: context.valid? and valid?}
  end
end
