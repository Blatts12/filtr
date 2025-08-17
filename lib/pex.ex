defmodule Pex do
  @moduledoc false

  alias Pex.Validator
  alias Pex.Caster

  @type supported_types ::
          :string
          | :integer
          | :float
          | :boolean
          | :date
          | :datetime
          | :list
          | {:list, supported_types()}
          | map()
          | nil

  @type pex_params :: map()
  @empty_pex_params %{}

  @spec run(schema :: map(), params :: map()) :: pex_params()
  @spec run(schema :: map(), params :: map(), opts :: keyword()) :: pex_params()
  def run(schema, params, run_opts \\ []) do
    no_errors? = Keyword.get(run_opts, :no_errors, false)

    Map.new(schema, fn
      {key, nested_schema} when is_map(nested_schema) ->
        values = get_value(params, key)
        {key, run(nested_schema, values, run_opts)}

      {key, opts} ->
        {type, opts} = Keyword.pop(opts, :type, :__none__)
        {default, opts} = Keyword.pop(opts, :default, :__none__)
        value = get_value(params, key, default)

        with {:ok, casted_value} <- Caster.run(value, type, opts),
             {:ok, validated_value} <- Validator.run(casted_value, type, opts) do
          {key, validated_value}
        else
          error ->
            if no_errors? do
              default_value = get_default(default, params, key)
              {key, default_value}
            else
              handle_error(error)
            end
        end
    end)
  end

  defp get_value(params, key), do: Map.get(params, to_string(key)) || Map.get(params, key)

  defp get_value(params, key, default) do
    value = get_value(params, key)

    case value do
      nil -> get_default(default, params, key)
      _ -> value
    end
  end

  defp get_default(default, _, _) when is_function(default, 0), do: default.()
  defp get_default(default, _, key) when is_function(default, 1), do: default.(key)
  defp get_default(default, params, key) when is_function(default, 2), do: default.(key, params)
  defp get_default(:__none__, _, _), do: nil
  defp get_default(default, _, _), do: default

  defp handle_error({:error, errors}) when is_list(errors), do: {:error, errors}
  defp handle_error({:error, error}), do: {:error, [error]}

  @spec empty_pex_params() :: pex_params()
  def empty_pex_params(), do: @empty_pex_params
end
