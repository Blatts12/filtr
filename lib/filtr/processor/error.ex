defmodule Filtr.Processor.Error do
  @moduledoc """
  Applies the error mode when a key fails to cast or validate.

  `:fallback` swaps in the key default and keeps going, `:strict` records the
  errors in the result, and `:raise` stops the run. A word of caution about
  `:fallback`: it hides bad input, so the caller never learns the value was
  wrong. Internal module, the API may change between releases.
  """

  alias Filtr.Processor.Default
  alias Filtr.Types

  @spec not_handled(Types.key(), Types.key_schema(), Types.context(), label :: String.t()) ::
          {:error, [Types.error()]} | {:ok, term()}
  def not_handled(key, key_schema, context, label) do
    mode = effective_error_mode(key_schema, context)
    error = missing_plugin_error(key_schema.type, label)
    invoke_error_mode(mode, [error], key, key_schema, context)
  end

  @spec missing_plugin_error(type :: term(), label :: String.t()) :: String.t()
  def missing_plugin_error(type, label), do: "missing #{label} for #{inspect(type)}"

  @spec handle_error(
          errors :: [Types.error()] | Types.error(),
          Types.key(),
          Types.key_schema(),
          Types.context()
        ) :: {:error, [Types.error()]} | {:ok, term()}
  def handle_error(errors, key, key_schema, context) do
    errors = List.wrap(errors)
    mode = effective_error_mode(key_schema, context)
    invoke_error_mode(mode, errors, key, key_schema, context)
  end

  @spec effective_error_mode(Types.key_schema(), Types.context()) :: Types.error_mode()
  def effective_error_mode(%{error_mode: error_mode}, _context), do: error_mode
  def effective_error_mode(_key_schema, %{error_mode: error_mode}), do: error_mode

  defp invoke_error_mode(:fallback, _errors, _key, key_schema, context) do
    value = Default.get_default(key_schema, context)
    {:ok, {:default, value}}
  end

  defp invoke_error_mode(:strict, errors, _key, _key_schema, _context) do
    {:error, errors}
  end

  defp invoke_error_mode(:raise, errors, key, _key_schema, _context) do
    error = parse_errors(errors)
    raise "Invalid value for #{key}: #{error}"
  end

  defp parse_errors(errors), do: Enum.map_join(errors, ",\n", &to_message/1)

  defp to_message(error) when is_binary(error), do: error
  defp to_message(error), do: inspect(error)
end
