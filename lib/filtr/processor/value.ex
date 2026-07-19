defmodule Filtr.Processor.Value do
  @moduledoc false

  alias Filtr.Processor.Cast
  alias Filtr.Processor.Context
  alias Filtr.Processor.Validate
  alias Filtr.Types

  @spec valid_value?(value :: Types.value()) :: boolean()
  def valid_value?({:error, _error}), do: false
  def valid_value?(_value), do: true

  @spec to_proper(value :: Types.value()) :: {:error, term()} | term()
  def to_proper({:ok, {:default, value}}), do: value
  def to_proper({:ok, value}), do: value
  def to_proper({:error, errors}) when is_list(errors), do: {:error, Enum.uniq(errors)}
  def to_proper({:error, error}), do: {:error, [error]}
  def to_proper(value), do: value

  @spec process_param(
          key :: Types.key(),
          key_schema :: Types.key_schema(),
          context :: Types.context()
        ) :: Types.context()
  def process_param(key, key_schema, context) do
    value = Context.get_param(context, key)

    case Cast.cast(key, key_schema, value, context) do
      {:ok, {:default, default_value}} ->
        Context.put_result(context, key, default_value)

      {:ok, casted_value} ->
        result = Validate.validate(key, key_schema, casted_value, context)
        proper = to_proper(result)
        Context.put_result(context, key, proper)

      error ->
        Context.put_result(context, key, error)
    end
  end

  @spec empty?(value :: term()) :: boolean()
  def empty?(nil), do: true
  def empty?(:__none__), do: true
  def empty?(""), do: true
  def empty?([]), do: true
  def empty?(map) when map == %{}, do: true
  def empty?(_value), do: false

  @spec fallback_none(value :: term(), fallback :: term()) :: term()
  def fallback_none(:__none__, fallback), do: fallback
  def fallback_none(value, _fallback), do: value
end
