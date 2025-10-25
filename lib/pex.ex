defmodule Pex do
  @moduledoc false

  alias Pex.Helpers

  @type_plugin_map Helpers.type_plugin_map()

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
    plugin = @type_plugin_map[type]

    if is_nil(plugin) do
      process_error_with_mode(key, "unsupported type - #{type}", opts)
    else
      case plugin.cast(value, type, opts) do
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
          @type_plugin_map[type].validate(value, type, validator, opts)
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
end
