defmodule Filtr.Processor.Context do
  @moduledoc false

  alias Filtr.Helpers
  alias Filtr.Processor.Value
  alias Filtr.Types

  @spec create_context(Types.params(), Types.opts()) :: Types.context()
  def create_context(params, opts) do
    %{
      result: [],
      params: params,
      valid?: true,
      plugin_map: Keyword.get_lazy(opts, :plugin_map, &Helpers.type_plugin_map/0),
      error_mode: Keyword.get_lazy(opts, :error_mode, &Helpers.default_error_mode/0),
      opts: opts
    }
  end

  @spec get_param(Types.context(), key :: atom()) :: term()
  def get_param(%{params: nil}, _key), do: :__none__

  def get_param(%{params: params}, key) do
    case params do
      %{^key => value} -> value
      _ -> Map.get(params, Atom.to_string(key), :__none__)
    end
  end

  @spec put_result(Types.context(), Types.key(), Types.value()) :: Types.context()
  def put_result(context, key, value) do
    valid? = Value.valid_value?(value)
    result = [{key, value} | context.result]
    %{context | result: result, valid?: context.valid? and valid?}
  end

  @spec put_nested_result(Types.context(), Types.key(), Types.context()) ::
          Types.context()
  def put_nested_result(context, key, result_context) do
    %{result: nested, valid?: valid?} = result_context
    result = [{key, :maps.from_list(nested)} | context.result]
    %{context | result: result, valid?: context.valid? and valid?}
  end

  @spec to_result(Types.context()) :: Types.result()
  def to_result(context), do: :maps.from_list([{:_valid?, context.valid?} | context.result])

  @spec plugin_for_type(Types.context(), type :: Types.plugin_type()) :: Types.plugin() | nil
  def plugin_for_type(%{plugin_map: plugin_map}, type) do
    case plugin_map do
      %{^type => plugin} -> plugin
      _ -> nil
    end
  end

  @spec plugin_for_type!(Types.context(), type :: Types.plugin_type()) :: Types.plugin()
  def plugin_for_type!(context, type),
    do: plugin_for_type(context, type) || raise("missing plugin for type #{inspect(type)}")
end
