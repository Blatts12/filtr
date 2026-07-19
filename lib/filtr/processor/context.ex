defmodule Filtr.Processor.Context do
  @moduledoc false

  alias Filtr.Helpers
  alias Filtr.Processor.Value
  alias Filtr.Types

  @spec create_context(params :: Types.params(), opts :: Types.opts()) :: Types.context()
  def create_context(params, opts) do
    {plugin_map, opts} = Keyword.pop_lazy(opts, :plugin_map, &Helpers.type_plugin_map/0)
    {error_mode, opts} = Keyword.pop_lazy(opts, :error_mode, &Helpers.default_error_mode/0)

    %{
      result: [],
      params: params,
      valid?: true,
      plugin_map: plugin_map,
      error_mode: error_mode,
      opts: opts
    }
  end

  @spec get_param(context :: Types.context(), key :: atom()) :: term()
  def get_param(%{params: nil}, _key), do: :__none__

  def get_param(%{params: params}, key) do
    case params do
      %{^key => value} -> value
      _ -> Map.get(params, Atom.to_string(key), :__none__)
    end
  end

  @spec put_result(context :: Types.context(), key :: Types.key(), value :: Types.value()) :: Types.context()
  def put_result(context, key, value) do
    valid? = Value.valid_value?(value)
    result = [{key, value} | context.result]
    %{context | result: result, valid?: context.valid? and valid?}
  end

  @spec put_nested_result(context :: Types.context(), key :: Types.key(), result_context :: Types.context()) ::
          Types.context()
  def put_nested_result(context, key, result_context) do
    %{result: nested, valid?: valid?} = result_context
    result = [{key, :maps.from_list(nested)} | context.result]
    %{context | result: result, valid?: context.valid? and valid?}
  end

  @spec to_result(context :: Types.context()) :: Types.result()
  def to_result(context), do: :maps.from_list([{:_valid?, context.valid?} | context.result])

  @spec plugin_for_type(context :: Types.context(), type :: Types.plugin_type()) :: Types.plugin() | nil
  def plugin_for_type(%{plugin_map: plugin_map}, type), do: plugin_map[type]

  @spec plugin_for_type!(context :: Types.context(), type :: Types.plugin_type()) :: Types.plugin()
  def plugin_for_type!(context, type), do: plugin_for_type(context, type) || raise("missing plugin for type #{type}")
end
