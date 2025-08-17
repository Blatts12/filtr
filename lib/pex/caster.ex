defmodule Pex.Caster do
  @moduledoc """
  Provides type casting functionality for converting raw parameter values to their expected types.

  This module handles the conversion of string-based parameters (typically from HTTP requests)
  into their appropriate Elixir data types. It supports all the basic types that Pex works with
  and allows for custom casting functions.

  ## Supported Type Casting

  ### Basic Types
  - `:string` - Validates string input (no conversion needed)
  - `:integer` - Converts strings to integers using `Integer.parse/1`
  - `:float` - Converts strings to floats using `Float.parse/1`
  - `:boolean` - Converts string representations to boolean values
  - `:date` - Converts ISO8601 date strings to `Date` structs
  - `:datetime` - Converts ISO8601 datetime strings to `DateTime` structs

  ### Collection Types
  - `:list` - Converts comma-separated strings to lists
  - `{:list, type}` - Converts comma-separated strings to lists of specified type

  ### Custom Types
  - Function types - Custom casting functions for specialized conversions

  ## Boolean Conversion

  The following string values are converted to booleans:
  - `true`: "true", "1", "yes"
  - `false`: "false", "0", "no"

  ## Examples

      # String casting (validation only)
      Caster.run("hello", :string)
      # => {:ok, "hello"}

      # Integer casting
      Caster.run("42", :integer)
      # => {:ok, 42}

      # Boolean casting
      Caster.run("true", :boolean)
      # => {:ok, true}

      # Date casting
      Caster.run("2023-12-25", :date)
      # => {:ok, ~D[2023-12-25]}

      # List casting
      Caster.run("apple,banana,orange", :list)
      # => {:ok, ["apple", "banana", "orange"]}

      # Typed list casting
      Caster.run("1,2,3", {:list, :integer})
      # => {:ok, [1, 2, 3]}

      # Custom casting
      Caster.run("HELLO", :string, [cast: &String.downcase/1])
      # => {:ok, "hello"}

  This module is typically used internally by `Pex.run/2` and `Pex.run/3`, but can be
  used directly for custom casting scenarios.
  """

  @doc """
  Casts a value to the specified type.

  This function attempts to convert a raw value (typically a string from HTTP parameters)
  to the specified Elixir type. It handles type conversion for all supported Pex types
  and allows for custom casting functions.

  ## Parameters

  - `value` - The value to cast (typically a string)
  - `type` - The target type (one of `Pex.supported_types()`)
  - `opts` - Optional keyword list including custom casting options

  ## Options

  - `:cast` - Custom casting function (arity 1, 2, or 3)

  ## Returns

  - `{:ok, casted_value}` when casting succeeds
  - `{:error, error_message}` when casting fails

  ## Examples

      # Basic type casting
      Caster.run("42", :integer)
      # => {:ok, 42}

      Caster.run("3.14", :float)
      # => {:ok, 3.14}

      Caster.run("true", :boolean)
      # => {:ok, true}

      # Date and datetime casting
      Caster.run("2023-12-25", :date)
      # => {:ok, ~D[2023-12-25]}

      Caster.run("2023-12-25T10:30:00Z", :datetime)
      # => {:ok, ~U[2023-12-25 10:30:00Z]}

      # List casting
      Caster.run("a,b,c", :list)
      # => {:ok, ["a", "b", "c"]}

      Caster.run("1,2,3", {:list, :integer})
      # => {:ok, [1, 2, 3]}

      # Custom casting function
      upcase_cast = fn value -> {:ok, String.upcase(value)} end
      Caster.run("hello", :string, [cast: upcase_cast])
      # => {:ok, "HELLO"}

      # Arity-2 custom casting (receives value and type)
      debug_cast = fn value, type ->
        IO.puts("Casting " <> inspect(value) <> " to " <> inspect(type))
        {:ok, value}
      end
      Caster.run("test", :string, [cast: debug_cast])

      # Arity-3 custom casting (receives value, type, and opts)
      context_cast = fn value, type, opts ->
        prefix = Keyword.get(opts, :prefix, "")
        {:ok, prefix <> value}
      end
      Caster.run("world", :string, [cast: context_cast, prefix: "hello "])
      # => {:ok, "hello world"}

  ## Error Cases

      # Invalid integer
      Caster.run("not_a_number", :integer)
      # => {:error, "invalid integer"}

      # Invalid boolean
      Caster.run("maybe", :boolean)
      # => {:error, "invalid boolean"}

      # Invalid date
      Caster.run("not-a-date", :date)
      # => {:error, "invalid date"}

  ## Special Values

  Empty strings and `nil` values are passed through unchanged for all types,
  allowing the validation layer to handle required field checks.

      Caster.run("", :integer)
      # => {:ok, ""}

      Caster.run(nil, :string)
      # => {:ok, nil}
  """
  @spec run(value :: any(), type :: Pex.supported_types()) ::
          {:ok, any()} | {:error, [binary()] | binary()}
  @spec run(value :: any(), type :: Pex.supported_types(), opts :: keyword()) ::
          {:ok, any()} | {:error, [binary()] | binary()}
  def run(value, type, opts \\ []) do
    cast_fn = opts[:cast] || (&cast/2)

    cond do
      is_function(cast_fn, 3) -> cast_fn.(value, type, opts)
      is_function(cast_fn, 2) -> cast_fn.(value, type)
      is_function(cast_fn, 1) -> cast_fn.(value)
      true -> raise "invalid cast function provided"
    end
  end

  defp cast(value, _type) when value in ["", nil], do: {:ok, value}

  # String
  defp cast(value, :string) when is_binary(value), do: {:ok, value}
  defp cast(_value, :string), do: {:error, "invalid string"}

  # Integer
  defp cast(value, :integer) when is_integer(value), do: {:ok, value}

  defp cast(value, :integer) do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      _ -> {:error, "invalid integer"}
    end
  end

  # Float
  defp cast(value, :float) when is_float(value), do: {:ok, value}

  defp cast(value, :float) do
    case Float.parse(value) do
      {float, _} -> {:ok, float}
      _ -> {:error, "invalid float"}
    end
  end

  # Boolean
  defp cast(value, :boolean) when is_boolean(value), do: {:ok, value}

  defp cast(value, :boolean) do
    case String.downcase(value) do
      v when v in ["true", "1", "yes"] -> {:ok, true}
      v when v in ["false", "0", "no"] -> {:ok, false}
      _ -> {:error, "invalid boolean"}
    end
  end

  # Date
  defp cast(%Date{} = date, :date), do: {:ok, date}

  defp cast(value, :date) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "invalid date"}
    end
  end

  # Datetime
  defp cast(%DateTime{} = datetime, :datetime), do: {:ok, datetime}

  defp cast(value, :datetime) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "invalid datetime"}
    end
  end

  # List
  defp cast(value, :list) when is_binary(value),
    do: cast(String.split(value, ",", trim: true), :list)

  defp cast(values, :list) when is_list(values), do: {:ok, values}
  defp cast(_value, :list), do: {:error, "invalid list"}

  # List with type
  defp cast(value, {:list, type}) when is_list(value) do
    results = Enum.map(value, &cast(&1, type))

    errors =
      Enum.filter(results, &match?({:error, _}, &1))
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()

    if errors == [],
      do: {:ok, Enum.map(results, &elem(&1, 1))},
      else: {:error, errors}
  end

  defp cast(value, {:list, type}) when is_binary(value) do
    values = String.split(value, ",", trim: true)
    cast(values, {:list, type})
  end

  defp cast(_value, {:list, _type}), do: {:error, "invalid list"}

  # Custom
  defp cast(value, cast_fn) when is_function(cast_fn, 1), do: cast_fn.(value)
  defp cast(value, :__none__), do: {:ok, value}
  defp cast(value, nil), do: {:ok, value}
  defp cast(_value, _type), do: {:error, "unsupported type"}
end
