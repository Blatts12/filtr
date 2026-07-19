defmodule Filtr.Processor.Error do
  @moduledoc false

  alias Filtr.Processor.Default
  alias Filtr.Types

  @spec not_handled(
          key :: Types.key(),
          key_schema :: Types.key_schema(),
          context :: Types.context(),
          label :: String.t()
        ) :: {:error, [Types.error()]} | {:ok, term()}
  def not_handled(key, key_schema, context, label) do
    mode = effective_error_mode(key_schema, context)
    error = missing_plugin_error(key_schema, label)
    invoke_error_mode(mode, [error], key, key_schema, context)
  end

  defp missing_plugin_error(%{type: type}, label), do: "missing #{label} for #{inspect(type)}"

  @spec handle_error(
          errors :: [Types.error()] | Types.error(),
          key :: Types.key(),
          key_schema :: Types.key_schema(),
          context :: Types.context()
        ) :: {:error, [Types.error()]} | {:ok, term()}
  def handle_error(errors, key, key_schema, context) do
    errors = List.wrap(errors)
    mode = effective_error_mode(key_schema, context)
    invoke_error_mode(mode, errors, key, key_schema, context)
  end

  @spec effective_error_mode(key_schema :: Types.key_schema(), context :: Types.context()) :: Types.error_mode()
  def effective_error_mode(key_schema, context) do
    Map.get(key_schema, :error_mode, context.error_mode)
  end

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

  defp parse_errors(errors), do: Enum.join(errors, ",\n")
end
