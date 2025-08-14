defmodule Pex.Validator do
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

  @common_opts [:required, :cast, :validate]
  @string_opts [:min, :max, :in, :pattern, :starts_with, :ends_with]
  @integer_opts [:min, :max, :in]
  @float_opts [:min, :max, :in]
  @date_opts [:min, :max, :in]
  @datetime_opts [:min, :max, :in]
  @list_opts [:min, :max]
  @none_opts []

  @supported_opts %{
    string: @string_opts,
    integer: @integer_opts,
    float: @float_opts,
    date: @date_opts,
    datetime: @datetime_opts,
    list: @list_opts,
    none: @none_opts
  }

  @spec run(map(), map()) :: keyword()
  def run(params, schema) do
    Keyword.new(schema, fn
      {key, map} when is_map(map) ->
        values = get_value(params, key)
        {key, run(values, map)}

      {key, opts} ->
        {type, opts} = Keyword.pop(opts, :type, :none)
        opts = Keyword.take(opts, @supported_opts[type] ++ @common_opts)
        value = get_value(params, key)

        case validate(value, type, opts) do
          {:ok, casted_value} -> {key, casted_value}
          error -> {key, error}
        end
    end)
  end

  @spec validate(any(), supported_types()) :: {:ok, any()} | {:error, [binary()]}
  @spec validate(any(), supported_types(), keyword()) :: {:ok, any()} | {:error, [binary()]}
  def validate(value, type, opts \\ []) do
    cast_fn = opts[:cast] || (&cast/2)

    with {:ok, casted_value} <- cast_value(value, type, cast_fn),
         :ok <- valid_value(casted_value, type, opts) do
      {:ok, casted_value}
    else
      {:error, error} when is_binary(error) -> {:error, [error]}
      {:error, errors} -> {:error, errors}
    end
  end

  defp cast_value(value, type, cast_fn) when is_function(cast_fn, 2), do: cast_fn.(value, type)
  defp cast_value(value, _type, cast_fn) when is_function(cast_fn, 1), do: cast_fn.(value)

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

  defp cast(_value, _type), do: {:error, "unsupported type"}

  defp valid_value(value, type, opts) do
    errors =
      Enum.map(opts, fn {opt, check} -> valid?(opt, value, type, check) end)
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(&elem(&1, 1))

    if errors == [],
      do: :ok,
      else: {:error, errors}
  end

  # Required
  defp valid?(:required, value, _type, true) do
    if value in ["", nil], do: {:error, "required"}, else: :ok
  end

  defp valid?(:required, _value, _type, false), do: :ok

  # In
  defp valid?(:in, values, :list, list) do
    if Enum.any?(values, &(&1 not in list)),
      do: {:error, "invalid value in list"},
      else: :ok
  end

  defp valid?(:in, value, _type, list) do
    if value in list, do: :ok, else: {:error, "value not in list"}
  end

  # Max
  defp valid?(:max, value, :string, max) do
    if String.length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} characters long"}
  end

  defp valid?(:max, value, :integer, max) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  defp valid?(:max, value, :float, max) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  defp valid?(:max, value, :date, max) do
    if Date.compare(value, max) in [:lt, :eq],
      do: :ok,
      else: {:error, "must be before or equal to #{max}"}
  end

  defp valid?(:max, value, :datetime, max) do
    if DateTime.compare(value, max) in [:lt, :eq],
      do: :ok,
      else: {:error, "must be before or equal to #{max}"}
  end

  defp valid?(:max, value, :list, max) do
    if length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} items long"}
  end

  # Min
  defp valid?(:min, value, :string, min) do
    if String.length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} characters long"}
  end

  defp valid?(:min, value, :integer, min) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  defp valid?(:min, value, :float, min) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  defp valid?(:min, value, :date, min) do
    if Date.compare(value, min) in [:gt, :eq],
      do: :ok,
      else: {:error, "must be after or equal to #{min}"}
  end

  defp valid?(:min, value, :datetime, min) do
    if DateTime.compare(value, min) in [:gt, :eq],
      do: :ok,
      else: {:error, "must be after or equal to #{min}"}
  end

  defp valid?(:min, value, :list, min) do
    if length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} items long"}
  end

  # Pattern
  defp valid?(:pattern, value, :string, pattern) do
    if value =~ pattern, do: :ok, else: {:error, "does not match pattern"}
  end

  # Starts with
  defp valid?(:starts_with, value, :string, prefix) do
    if String.starts_with?(value, prefix),
      do: :ok,
      else: {:error, "does not start with #{prefix}"}
  end

  # Ends with
  defp valid?(:ends_with, value, :string, suffix) do
    if String.ends_with?(value, suffix),
      do: :ok,
      else: {:error, "does not end with #{suffix}"}
  end

  # Custom
  defp valid?(:validate, value, _type, valid_fn) when is_function(valid_fn, 1) do
    case valid_fn.(value) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
      false -> {:error, "validation failed"}
      _ -> :ok
    end
  end

  # Skip validation options that are not actual validations
  defp valid?(opt, _value, _type, _check) when opt in [:cast, :type], do: :ok

  defp valid?(op, _value, type, _check), do: raise("unsupported validation: #{op}, type: #{type}")

  defp get_value(params, key), do: Map.get(params, to_string(key)) || Map.get(params, key)
end
