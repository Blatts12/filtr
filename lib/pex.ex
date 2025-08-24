defmodule Pex do
  @moduledoc """
  Pex is a powerful Elixir library for parsing and validating query parameters
  in Phoenix controllers and LiveViews using declarative schemas with custom validators.

  ## Features

  - **Declarative Schemas** - Define parameter validation rules using simple maps
  - **Type Casting** - Automatic conversion between string parameters and Elixir types
  - **Custom Validators** - Built-in validators plus support for custom validation functions
  - **Decorator Integration** - Clean controller annotations using the decorator package
  - **Phoenix Integration** - Seamless integration with Phoenix controllers and LiveViews
  - **Comprehensive Error Handling** - Detailed error messages for validation failures
  - **Error Mode Control** - Flexible error handling with :fallback, :strict, :raise, and custom halt options

  ## Basic Usage

      # Define a schema for your parameters
      schema = %{
        name: [type: :string, required: true],
        age: [type: :integer, min: 0, max: 120],
        email: [type: :string, pattern: ~r/@/],
        tags: [type: {:list, :string}]
      }

      # Parse and validate parameters
      params = %{"name" => "John", "age" => "25", "email" => "john@example.com", "tags" => "elixir,phoenix"}
      result = Pex.run(schema, params)
      # => %{name: "John", age: 25, email: "john@example.com", tags: ["elixir", "phoenix"]}

  ## Schema Definition

  Schemas are defined as maps where keys represent parameter names and values contain
  validation and casting options:

      schema = %{
        param_name: [type: :string, required: true, min: 5],
        optional_param: [type: :integer, default: 42]
      }

  ## Supported Types

  - `:string` - String values
  - `:integer` - Integer numbers
  - `:float` - Floating point numbers
  - `:boolean` - Boolean values (true/false)
  - `:date` - Date values (ISO8601 format)
  - `:datetime` - DateTime values (ISO8601 format)
  - `:list` - List of strings
  - `{:list, type}` - List of specified type

  ## Error Handling

  By default, Pex returns default values when validation fails. Use the `:error_mode`
  option to control error handling behavior.

      # Fallback mode (default)
      Pex.run(schema, invalid_params, error_mode: :fallback)
      # => %{param: default_value}

      # Strict mode
      Pex.run(schema, invalid_params)
      # => {:error, ["validation failed"]}

      # Raise mode
      Pex.run(schema, invalid_params, error_mode: :raise)
      # => raises ArgumentError

      # Custom function mode
      Pex.run(schema, invalid_params, error_mode: fn _errors -> :custom_response end)
      # => :custom_response
  """

  alias Pex.Caster
  alias Pex.Validator

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

  @supported_types [
    :string,
    :integer,
    :float,
    :boolean,
    :date,
    :datetime,
    :list,
    nil
  ]

  @doc """
  Parses and validates parameters according to the provided schema.

  This is the main function of the Pex library. It takes a schema definition and
  raw parameters (typically from a web request) and returns a map of validated
  and type-cast parameters.

  ## Parameters

  - `schema` - A map defining the expected parameters and their validation rules
  - `params` - A map of raw parameter values (typically strings from query parameters)
  - `opts` - Optional keyword list of runtime options

  ## Options

  - `:error_mode` - Controls error handling behavior:
    - `:fallback` (default) - Returns default values instead of errors
    - `:strict` - Returns `{:error, errors}` tuple
    - `:raise` - Raises exceptions on validation errors
    - `function` - Calls custom function with errors and returns its result

  ## Examples

      schema = %{
        name: [type: :string, required: true],
        age: [type: :integer, min: 0, max: 120]
      }

      # Valid parameters
      Pex.run(schema, %{"name" => "John", "age" => "25"})
      # => %{name: "John", age: 25}

      # Invalid parameters (fallback mode)
      Pex.run(schema, %{"age" => "invalid"}, error_mode: :fallback)
      # => %{name: nil, age: nil}

      # Invalid parameters (strict mode)
      Pex.run(schema, %{"age" => "invalid"})
      # => {:error, ["required", "invalid integer"]}

      # Invalid parameters (raise mode)
      Pex.run(schema, %{"age" => "invalid"}, error_mode: :raise)
      # => raises ArgumentError

      # Invalid parameters (custom function)
      Pex.run(schema, %{"age" => "invalid"}, error_mode: fn _key, _errors -> :failed end)
      # => :failed

  ## Nested Schemas

  Schemas can be nested to handle complex parameter structures:

      schema = %{
        user: %{
          name: [type: :string, required: true],
          age: [type: :integer, min: 0]
        }
      }

      Pex.run(schema, %{"user" => %{"name" => "John", "age" => "25"}})
      # => %{user: %{name: "John", age: 25}}
  """
  @spec run(schema :: map(), params :: map()) :: pex_params()
  @spec run(schema :: map(), params :: map(), opts :: keyword()) :: pex_params()
  def run(schema, params, run_opts \\ []) do
    error_mode = Keyword.get(run_opts, :error_mode, :fallback)

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
            handle_error_with_mode(error, error_mode, default, params, key)
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

  defp handle_error_with_mode(error, :strict, _default, _params, key) do
    {key, handle_error(error)}
  end

  defp handle_error_with_mode(_error, :fallback, default, params, key) do
    default_value = get_default(default, params, key)
    {key, default_value}
  end

  defp handle_error_with_mode(error, :raise, _default, _params, key) do
    {:error, errors} = handle_error(error)
    raise ArgumentError, "Validation failed for #{key}: #{Enum.join(errors, ", ")}"
  end

  defp handle_error_with_mode(error, func, _default, params, key) do
    {:error, errors} = handle_error(error)

    cond do
      is_function(func, 2) -> func.(key, errors)
      is_function(func, 3) -> func.(key, errors, params)
      true -> raise "Invalid error mode: #{inspect(func)}"
    end
  end

  defp handle_error({:error, errors}) when is_list(errors), do: {:error, errors}
  defp handle_error({:error, error}), do: {:error, [error]}

  @doc """
  Returns an empty Pex parameters map.

  This function provides a consistent way to create an empty parameter map
  that matches the type expected by Pex functions. Useful as a fallback
  when no parameters are available.

  ## Examples

      Pex.empty_pex_params()
      # => %{}

      # Useful as a fallback
      params = socket.assigns[:pex] || Pex.empty_pex_params()
  """
  @spec empty_pex_params() :: pex_params()
  def empty_pex_params, do: @empty_pex_params

  @doc """
  Returns a list of supported parameter types.
  """
  @spec supported_types() :: [Pex.supported_types()]
  def supported_types, do: @supported_types
end
