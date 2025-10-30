defmodule Filtr do
  @moduledoc """
    Main file
  """

  alias Filtr.Helpers

  require Logger

  @spec run(schema :: map(), params :: map()) :: map()
  @spec run(schema :: map(), params :: map(), opts :: keyword()) :: map()
  def run(schema, params, run_opts \\ []) do
    Map.new(schema, fn
      {key, nested_schema} when is_map(nested_schema) ->
        values = get_value(params, key)
        {key, run(nested_schema, values, run_opts)}

      {key, opts} ->
        opts = Keyword.merge(run_opts, opts)
        {type, opts} = Keyword.pop!(opts, :type)

        case type do
          {:list, nested_schema} when is_map(nested_schema) ->
            values = get_value(params, key)
            {key, run(nested_schema, values, run_opts)}

          {:list, type} ->
            values =
              params
              |> get_value(key)
              |> Enum.map(fn value ->
                key
                |> process_value(value, type, opts)
                |> elem(1)
              end)

            {key, values}

          type ->
            value = get_value(params, key)
            process_value(key, value, type, opts)
        end
    end)
  end

  defp process_value(key, value, type, opts) do
    with {:ok, value} <- cast(key, value, type, opts),
         {:ok, value} <- validate(key, value, type, opts) do
      {key, value}
    else
      error -> {key, error}
    end
  end

  defp cast(key, value, cast_fn, opts) when is_function(cast_fn, 2) do
    case cast_fn.(value, opts) do
      {:ok, value} -> {:ok, value}
      {:error, errors} when is_list(errors) -> process_errors_with_mode(key, errors, opts)
      {:error, error} -> process_error_with_mode(key, error, opts)
      value -> {:ok, value}
    end
  end

  defp cast(_key, value, :__none__, _opts), do: {:ok, value}
  defp cast(_key, value, nil, _opts), do: {:ok, value}

  defp cast(key, nil, _type, opts) do
    validators = Keyword.get(opts, :validators, [])
    default = Keyword.get(validators, :default, :__none__)
    required? = Keyword.get(validators, :required, false)

    if required? and default == :__none__ do
      process_error_with_mode(key, "required", opts)
    else
      {:ok, default_value(default)}
    end
  end

  defp cast(key, value, type, opts) do
    plugins = Helpers.type_plugin_map()[type]

    if is_nil(plugins) do
      process_error_with_mode(key, "unsupported type - #{type}", opts)
    else
      case plugin_cast(plugins, value, type, opts) do
        {:ok, value} -> {:ok, value}
        {:error, error} -> process_error_with_mode(key, error, opts)
      end
    end
  end

  defp default_value(default) when is_function(default, 0), do: default.()
  defp default_value(:__none__), do: nil
  defp default_value(default), do: default

  defp validate(key, value, type, opts) do
    validators = Keyword.get(opts, :validators, [])

    errors =
      validators
      |> Keyword.drop([:default, :required])
      |> Enum.map(fn
        {:custom, func} when is_function(func, 3) ->
          func.(value, type, opts)

        {:custom, func} when is_function(func, 2) ->
          func.(value, type)

        {:custom, func} when is_function(func, 1) ->
          func.(value)

        validator ->
          plugins = Helpers.type_plugin_map()[type]
          plugin_validate(plugins, value, type, validator, opts)
      end)
      |> process_validator_results()

    case errors do
      [] -> {:ok, value}
      errors -> process_errors_with_mode(key, errors, opts)
    end
  end

  defp process_validator_results(results) do
    Enum.reduce(results, [], fn result, acc ->
      case result do
        true -> acc
        :ok -> acc
        {:ok, _} -> acc
        false -> acc ++ ["invalid value"]
        :error -> acc ++ ["invalid value"]
        {:error, error} -> acc ++ [error]
      end
    end)
  end

  defp process_error_with_mode(key, error, opts) do
    error_mode = Keyword.get_lazy(opts, :error_mode, fn -> Helpers.default_error_mode() end)
    validators = Keyword.get(opts, :validators, [])
    default = Keyword.get(validators, :default, :__none__)

    case error_mode do
      :fallback -> {:ok, default_value(default)}
      :strict -> {:error, [error]}
      :raise -> raise "Invalid value for #{key}: #{error}"
    end
  end

  defp process_errors_with_mode(key, errors, opts) do
    error_mode = Keyword.get_lazy(opts, :error_mode, fn -> Helpers.default_error_mode() end)
    validators = Keyword.get(opts, :validators, [])
    default = Keyword.get(validators, :default, :__none__)

    case error_mode do
      :fallback -> {:ok, default_value(default)}
      :strict -> {:error, Enum.uniq(errors)}
      :raise -> raise "Invalid value for #{key}: #{Enum.join(Enum.uniq(errors), ", ")}"
    end
  end

  defp get_value(params, key) do
    Map.get(params, to_string(key)) || Map.get(params, key)
  end

  defp plugin_cast(plugins, value, type, opts) do
    Enum.reduce_while(plugins, {:error, "missing cast for #{type}"}, fn plugin, result ->
      try do
        plugin.cast(value, type, opts)
      catch
        FunctionClauseError -> {:cont, result}
      else
        result -> {:halt, result}
      end
    end)
  end

  defp plugin_validate(plugins, value, type, validator, opts) do
    Enum.reduce_while(
      plugins,
      {:error, "missing validate for #{type}, #{inspect(validator)}"},
      fn plugin, result ->
        try do
          plugin.validate(value, type, validator, opts)
        catch
          FunctionClauseError -> {:cont, result}
        else
          result -> {:halt, result}
        end
      end
    )
  end

  @doc """
  Collects all errors from a Filtr result map into a structured error map.

  This function is primarily useful when using `:strict` error mode, where errors
  are returned as `{:error, [...]}` tuples in the result map rather than being
  replaced with default values (`:fallback`) or raising exceptions (`:raise`).

  This function traverses the result map returned by `Filtr.run/2` or `Filtr.run/3` and extracts
  all error tuples, organizing them into a hierarchical structure that mirrors the
  original schema structure.
  ## Examples

      iex> result = %{name: {:error, "required"}, age: 25}
      iex> Filtr.collect_errors(result)
      %{name: ["required"]}


      iex> result = %{name: "John", age: 25}
      iex> Filtr.collect_errors(result)
      nil

      iex> result = %{
      ...>   user: %{
      ...>     name: {:error, "required"},
      ...>     age: 25
      ...>   }
      ...> }
      iex> Filtr.collect_errors(result)
      %{user: %{name: ["required"]}}

      iex> result = %{tags: ["valid", {:error, "too short"}, "another"]}
      iex> Filtr.collect_errors(result)
      %{tags: %{1 => ["too short"]}}

      iex> result = %{
      ...>   users: [
      ...>     %{id: 1, name: "john"},
      ...>     %{id: 2, name: {:error, "required"}}
      ...>   ]
      ...> }
      iex> Filtr.collect_errors(result)
      %{users: %{1 => %{name: ["required"]}}}

  """
  @spec collect_errors(filtr_result :: map()) :: map() | nil
  def collect_errors(filtr_result) do
    errors = do_collect_errors(filtr_result)
    if errors == %{}, do: nil, else: errors
  end

  defp do_collect_errors(filtr_result) do
    Enum.reduce(filtr_result, %{}, fn
      {key, {:error, errors}}, acc ->
        Map.put(acc, key, List.wrap(errors))

      {key, value}, acc when is_map(value) ->
        errors = do_collect_errors(value)
        if errors == %{}, do: acc, else: Map.put(acc, key, errors)

      {key, [value | _] = values}, acc when is_map(value) ->
        errors =
          values
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn {value, index}, nested_acc ->
            nested_errors = do_collect_errors(value)
            if nested_errors == %{}, do: nested_acc, else: Map.put(nested_acc, index, nested_errors)
          end)

        if errors == %{}, do: acc, else: Map.put(acc, key, errors)

      {key, values}, acc when is_list(values) ->
        errors =
          values
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn
            {{:error, error}, index}, nested_acc -> Map.put(nested_acc, index, List.wrap(error))
            _, nested_acc -> nested_acc
          end)

        if errors == %{}, do: acc, else: Map.put(acc, key, errors)

      _, acc ->
        acc
    end)
  end
end
