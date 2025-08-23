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

  By default, Pex returns `{:error, errors}` when validation fails. Use the `:error_mode`
  option to control error handling behavior.

      # Strict mode (default)
      Pex.run(schema, invalid_params)
      # => {:error, ["validation failed"]}

      # Fallback mode
      Pex.run(schema, invalid_params, error_mode: :fallback)
      # => %{param: default_value}

      # Raise mode
      Pex.run(schema, invalid_params, error_mode: :raise)
      # => raises ArgumentError

      # Custom function mode
      Pex.run(schema, invalid_params, error_mode: fn _errors -> :custom_response end)
      # => :custom_response
  """

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
    - `:strict` (default) - Returns `{:error, errors}` tuple
    - `:fallback` - Returns default values instead of errors
    - `:raise` - Raises exceptions on validation errors
    - `function` - Calls custom function with errors and returns its result

  ## Returns

  - A map of validated and cast parameters when successful
  - `{:error, errors}` when validation fails and `:error_mode` is `:strict` (default)
  - Default values when validation fails and `:error_mode` is `:fallback`
  - Raises exception when validation fails and `:error_mode` is `:raise`
  - Custom result when validation fails and `:error_mode` is `function`

  ## Examples

      schema = %{
        name: [type: :string, required: true],
        age: [type: :integer, min: 0, max: 120]
      }

      # Valid parameters
      Pex.run(schema, %{"name" => "John", "age" => "25"})
      # => %{name: "John", age: 25}

      # Invalid parameters (strict mode)
      Pex.run(schema, %{"age" => "invalid"})
      # => {:error, ["required", "invalid integer"]}

      # Invalid parameters (fallback mode)
      Pex.run(schema, %{"age" => "invalid"}, error_mode: :fallback)
      # => %{name: nil, age: nil}

      # Invalid parameters (raise mode)
      Pex.run(schema, %{"age" => "invalid"}, error_mode: :raise)
      # => raises ArgumentError

      # Invalid parameters (custom function)
      Pex.run(schema, %{"age" => "invalid"}, error_mode: fn _errors -> :failed end)
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
    error_mode = Keyword.get(run_opts, :error_mode, :strict)

    try do
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
    catch
      {:halt_return, result} -> result
    end
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

  defp handle_error_with_mode(error, :strict, _default, _params, _key) do
    handle_error(error)
  end

  defp handle_error_with_mode(_error, :fallback, default, params, key) do
    default_value = get_default(default, params, key)
    {key, default_value}
  end

  defp handle_error_with_mode(error, :raise, _default, _params, _key) do
    errors = case error do
      {:error, errors} when is_list(errors) -> errors
      {:error, error} -> [error]
    end
    raise ArgumentError, "Validation failed: #{Enum.join(errors, ", ")}"
  end

  defp handle_error_with_mode(error, halt_fn, _default, _params, _key) when is_function(halt_fn, 1) do
    errors = case error do
      {:error, errors} when is_list(errors) -> errors
      {:error, error} -> [error]
    end
    throw({:halt_return, halt_fn.(errors)})
  end

  defp handle_error({:error, errors}) when is_list(errors), do: {:error, errors}
  defp handle_error({:error, error}), do: {:error, [error]}

  @doc """
  Returns an empty Pex parameters map.

  This function provides a consistent way to create an empty parameter map
  that matches the type expected by Pex functions. Useful as a fallback
  when no parameters are available.

  ## Returns

  An empty map representing no parameters.

  ## Examples

      Pex.empty_pex_params()
      # => %{}

      # Useful as a fallback
      params = socket.assigns[:pex] || Pex.empty_pex_params()
  """
  @spec empty_pex_params() :: pex_params()
  def empty_pex_params(), do: @empty_pex_params
end
