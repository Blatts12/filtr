defmodule Pex.Caster do
  @moduledoc false

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
