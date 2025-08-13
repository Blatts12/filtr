defmodule Pex do
  @moduledoc """
  Pex is a library for parsing and validating query parameters in Phoenix controllers and LiveViews.

  It provides a declarative way to define parameter schemas with custom validators
  and integrates with the decorator package for clean controller annotations.

  ## Example

      defmodule MyAppWeb.UserController do
        use Phoenix.Controller
        use Pex.Controller

        @pex_schema %{
          page: [type: :integer, default: 1, validator: &Pex.Validators.positive/1],
          limit: [type: :integer, default: 10, validator: &Pex.Validators.range(&1, 1, 100)],
          search: [type: :string, optional: true]
        }
        def index(conn, _params) do
          # Validated params available as conn.assigns.pex_params
          render(conn, "index.html")
        end
      end
  """

  @type schema_field :: %{
          type: :string | :integer | :float | :boolean | :list,
          default: any(),
          optional: boolean(),
          validator: (any() -> {:ok, any()} | {:error, String.t()})
        }

  @type schema :: %{atom() => schema_field()}

  @doc """
  Parses and validates query parameters according to the provided schema.

  ## Parameters
  - `params` - Raw query parameters (typically from conn.params)
  - `schema` - Schema definition for validation

  ## Returns
  - `{:ok, validated_params}` - On successful validation
  - `{:error, errors}` - On validation failure

  ## Examples

      iex> schema = %{page: [type: :integer, default: 1]}
      iex> Pex.parse(%{"page" => "2"}, schema)
      {:ok, %{page: 2}}

      iex> schema = %{page: [type: :integer, default: 1]}
      iex> Pex.parse(%{}, schema)
      {:ok, %{page: 1}}
  """
  @spec parse(map(), schema()) :: {:ok, map()} | {:error, map()}
  def parse(params, schema) when is_map(params) and is_map(schema) do
    Enum.reduce_while(schema, {:ok, %{}}, fn {field, field_spec}, {:ok, acc} ->
      case parse_field(params, field, field_spec) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, field, value)}}
        {:error, error} -> {:halt, {:error, %{field => error}}}
      end
    end)
  end

  defp parse_field(params, field, field_spec) do
    field_str = to_string(field)
    raw_value = Map.get(params, field_str)

    case {raw_value, field_spec} do
      {nil, spec} when is_list(spec) ->
        if Keyword.get(spec, :optional, false) do
          {:ok, nil}
        else
          default = Keyword.get(spec, :default)
          if default != nil, do: validate_value(default, spec), else: {:error, "required"}
        end

      {value, spec} when is_list(spec) ->
        with {:ok, typed_value} <- cast_type(value, Keyword.get(spec, :type, :string)),
             {:ok, validated_value} <- validate_value(typed_value, spec) do
          {:ok, validated_value}
        end
    end
  end

  defp cast_type(value, :string), do: {:ok, to_string(value)}
  defp cast_type(value, :integer) when is_integer(value), do: {:ok, value}
  defp cast_type(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "invalid integer"}
    end
  end
  defp cast_type(value, :float) when is_float(value), do: {:ok, value}
  defp cast_type(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "invalid float"}
    end
  end
  defp cast_type(value, :boolean) when is_boolean(value), do: {:ok, value}
  defp cast_type(value, :boolean) when is_binary(value) do
    case String.downcase(value) do
      v when v in ["true", "1", "yes"] -> {:ok, true}
      v when v in ["false", "0", "no"] -> {:ok, false}
      _ -> {:error, "invalid boolean"}
    end
  end
  defp cast_type(value, :list) when is_list(value), do: {:ok, value}
  defp cast_type(value, :list) when is_binary(value) do
    {:ok, String.split(value, ",")}
  end
  defp cast_type(_value, type), do: {:error, "unsupported type: #{type}"}

  defp validate_value(value, spec) do
    validator = Keyword.get(spec, :validator)
    
    if validator && is_function(validator, 1) do
      validator.(value)
    else
      {:ok, value}
    end
  end
end
