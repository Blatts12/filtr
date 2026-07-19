defmodule Filtr.Processor.Validate do
  @moduledoc false

  alias Filtr.Processor.Context
  alias Filtr.Processor.Default
  alias Filtr.Processor.Error
  alias Filtr.Processor.Value

  def validate(key, key_schema, :__none__, context) do
    required? = Map.get(key_schema, :required, false)

    if required? do
      Error.handle_error(["required"], key, key_schema, context)
    else
      {:ok, Default.get_default(key_schema, context)}
    end
  end

  def validate(key, key_schema, value, context) do
    required? = Map.get(key_schema, :required, false)
    validators = Map.get(key_schema, :validators, [])

    if validators == [] and not required? do
      {:ok, value}
    else
      do_validate(key, key_schema, value, required?, validators, context)
    end
  end

  defp do_validate(key, key_schema, value, required?, validators, context) do
    plugin = Context.plugin_for_type(context, key_schema.type)

    with :ok <- validate_required(required?, value, context),
         :ok <- validator(validators, [], value, key_schema.type, plugin, context) do
      {:ok, value}
    else
      :not_handled ->
        Error.not_handled(key, key_schema, context, "validation")

      {:error, errors} ->
        Error.handle_error(errors, key, key_schema, context)
    end
  end

  defp validate_required(required?, value, _context) do
    if required? and Value.empty?(value),
      do: {:error, ["required"]},
      else: :ok
  end

  defp validator([], [], _value, _type, _plugin, _context), do: :ok
  defp validator([], [_ | _] = current_errors, _value, _type, _plugin, _context), do: {:error, current_errors}

  defp validator([{:custom, func} | rest], current_errors, value, type, plugin, context) when is_function(func) do
    result =
      cond do
        is_function(func, 1) -> func.(value)
        is_function(func, 2) -> func.(value, type)
        is_function(func, 3) -> func.(value, type, context)
      end

    validator_result(result, rest, current_errors, value, type, plugin, context)
  end

  defp validator([validator | rest], current_errors, value, type, plugin, context) do
    if plugin do
      value
      |> plugin.validate(type, validator, context)
      |> validator_result(rest, current_errors, value, type, plugin, context)
    else
      validator_result({:error, "missing plugin for type #{type}"}, rest, current_errors, value, type, plugin, context)
    end
  end

  defp validator_result(:not_handled, _rest, _current_errors, _value, _type, _plugin, _context), do: :not_handled

  defp validator_result(true, rest, current_errors, value, type, plugin, context),
    do: validator(rest, current_errors, value, type, plugin, context)

  defp validator_result(:ok, rest, current_errors, value, type, plugin, context),
    do: validator(rest, current_errors, value, type, plugin, context)

  defp validator_result({:ok, _}, rest, current_errors, value, type, plugin, context),
    do: validator(rest, current_errors, value, type, plugin, context)

  defp validator_result(false, rest, current_errors, value, type, plugin, context),
    do: validator(rest, ["invalid value" | current_errors], value, type, plugin, context)

  defp validator_result(:error, rest, current_errors, value, type, plugin, context),
    do: validator(rest, ["invalid value" | current_errors], value, type, plugin, context)

  defp validator_result({:error, errors}, rest, current_errors, value, type, plugin, context) when is_list(errors),
    do: validator(rest, errors ++ current_errors, value, type, plugin, context)

  defp validator_result({:error, error}, rest, current_errors, value, type, plugin, context),
    do: validator(rest, [error | current_errors], value, type, plugin, context)
end
